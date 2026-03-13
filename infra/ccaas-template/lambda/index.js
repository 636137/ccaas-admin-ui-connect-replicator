/**
 * Census Enumerator AI Agent - Lambda Backend
 * 
 * WHAT THIS FILE DOES:
 * - Handles ALL backend operations for the census survey
 * - Stores and retrieves data from DynamoDB
 * - Called by Amazon Connect contact flow and Lex bot
 * 
 * KEY ACTIONS:
 * - lookupAddress: Find constituent's address by phone number
 * - verifyAddress: Confirm address is correct or record correction
 * - savePerson: Store demographic data for one household member
 * - saveSurvey: Finalize and store complete survey
 * - scheduleCallback: Record callback request
 * - generateConfirmation: Create confirmation number for completed survey
 * 
 * HOW IT'S CALLED:
 * - Contact Flow invokes with: { Details: { Parameters: { action: "lookupAddress", ... }}}
 * - Returns attributes that Contact Flow can use in next steps
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS clients - region from environment or default to us-east-1
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(dynamoClient);
const bedrockClient = new BedrockRuntimeClient({ region: process.env.AWS_REGION || 'us-east-1' });

// Table names - set via Terraform environment variables or use defaults
const CENSUS_TABLE = process.env.CENSUS_TABLE_NAME || 'CensusResponses';
const ADDRESS_TABLE = process.env.ADDRESS_TABLE_NAME || 'CensusAddresses';

/**
 * Main Lambda handler - routes requests to appropriate function based on 'action' parameter
 * 
 * Event structure from Connect: { Details: { Parameters: { action: "...", ...params }}}
 * Direct invocation: { action: "...", ...params }
 */
exports.handler = async (event) => {
    console.log('Event received:', JSON.stringify(event, null, 2));
    
    // Support both Connect contact flow format and direct invocation
    const action = event.Details?.Parameters?.action || event.action;
    
    try {
        switch (action) {
            case 'lookupAddress':
                return await lookupAddress(event);
            case 'verifyAddress':
                return await verifyAddress(event);
            case 'savePerson':
                return await savePersonInfo(event);
            case 'saveSurvey':
                return await saveSurvey(event);
            case 'scheduleCallback':
                return await scheduleCallback(event);
            case 'processAIResponse':
                return await processAIResponse(event);
            case 'generateConfirmation':
                return await generateConfirmationNumber(event);
            default:
                return {
                    statusCode: 400,
                    error: 'Unknown action',
                    message: `Action '${action}' is not supported`
                };
        }
    } catch (error) {
        console.error('Error processing request:', error);
        return {
            statusCode: 500,
            error: 'InternalError',
            message: error.message
        };
    }
};

/**
 * Look up address by phone number
 * 
 * WHY: We need to know which address the constituent is calling about
 * HOW: Query CensusAddresses table using phone number index
 * 
 * For demo/testing: Returns mock data if no address found
 */
async function lookupAddress(event) {
    const phoneNumber = event.Details?.Parameters?.phoneNumber || 
                        event.Details?.ContactData?.CustomerEndpoint?.Address ||
                        event.phoneNumber;
    
    // Normalize phone number - remove +1, spaces, dashes for consistent lookup
    const normalizedPhone = phoneNumber?.replace(/[\s\-\+]/g, '').replace(/^1/, '');
    
    console.log(`Looking up address for phone: ${normalizedPhone}`);
    
    try {
        // Query by phone number using Global Secondary Index
        const result = await docClient.send(new QueryCommand({
            TableName: ADDRESS_TABLE,
            IndexName: 'phoneNumber-index',
            KeyConditionExpression: 'phoneNumber = :phone',
            ExpressionAttributeValues: {
                ':phone': normalizedPhone
            },
            Limit: 1
        }));
        
        if (result.Items && result.Items.length > 0) {
            const address = result.Items[0];
            return {
                addressFound: 'true',
                addressId: address.addressId,
                streetAddress: address.streetAddress,
                city: address.city,
                state: address.state,
                zipCode: address.zipCode,
                caseId: address.caseId || uuidv4(),
                attemptNumber: (address.attemptNumber || 0) + 1
            };
        } else {
            // DEMO MODE: Return fake address for testing if not found
            // In production, you'd return addressFound: 'false' and handle accordingly
            return {
                addressFound: 'true',
                addressId: 'DEMO-' + normalizedPhone,
                streetAddress: '123 Main Street',
                city: 'Springfield',
                state: 'IL',
                zipCode: '62701',
                caseId: 'CASE-' + uuidv4().substring(0, 8),
                attemptNumber: 1
            };
        }
    } catch (error) {
        console.error('Error looking up address:', error);
        // Fallback to demo data on error - ensures testing works even without DB setup
        return {
            addressFound: 'true',
            addressId: 'DEMO-' + (normalizedPhone || 'unknown'),
            streetAddress: '123 Main Street',
            city: 'Springfield', 
            state: 'IL',
            zipCode: '62701',
            caseId: 'CASE-' + uuidv4().substring(0, 8),
            attemptNumber: 1
        };
    }
}

/**
 * Verify if the address is correct - called after constituent confirms or corrects
 */
async function verifyAddress(event) {
    const params = event.Details?.Parameters || event;
    const { caseId, isCorrect, correctedAddress } = params;
    
    if (isCorrect === 'false' && correctedAddress) {
        // Constituent provided a different address - record it for follow-up
        await docClient.send(new UpdateCommand({
            TableName: ADDRESS_TABLE,
            Key: { addressId: params.addressId },
            UpdateExpression: 'SET correctedAddress = :addr, addressVerified = :verified, verifiedAt = :time',
            ExpressionAttributeValues: {
                ':addr': correctedAddress,
                ':verified': false,
                ':time': new Date().toISOString()
            }
        }));
    }
    
    return {
        addressVerified: isCorrect,
        caseId: caseId,
        proceedWithSurvey: isCorrect === 'true'
    };
}

/**
 * Save person information during survey
 */
async function savePersonInfo(event) {
    const params = event.Details?.Parameters || event;
    const {
        caseId,
        personNumber,
        firstName,
        lastName,
        relationship,
        sex,
        dateOfBirth,
        age,
        hispanicLatino,
        hispanicOrigin,
        race,
        raceDetail
    } = params;
    
    const personData = {
        caseId,
        personNumber: parseInt(personNumber),
        firstName,
        lastName,
        relationship,
        sex,
        dateOfBirth,
        age: parseInt(age),
        hispanicLatino: hispanicLatino === 'true' || hispanicLatino === true,
        hispanicOrigin: hispanicOrigin || null,
        race: Array.isArray(race) ? race : [race],
        raceDetail: raceDetail || null,
        recordedAt: new Date().toISOString()
    };
    
    await docClient.send(new PutCommand({
        TableName: CENSUS_TABLE,
        Item: {
            caseId: caseId,
            timestamp: `PERSON#${personNumber}`,
            type: 'PERSON',
            data: personData
        }
    }));
    
    return {
        success: true,
        personNumber: personNumber,
        message: `Person ${personNumber} information saved`
    };
}

/**
 * Save completed survey
 */
async function saveSurvey(event) {
    const params = event.Details?.Parameters || event;
    const { caseId, surveyData, status, householdCount, housingTenure, contactPhone } = params;
    
    const confirmationNumber = generateConfirmationCode();
    
    const surveyRecord = {
        caseId,
        timestamp: new Date().toISOString(),
        type: 'SURVEY_COMPLETE',
        status: status || 'COMPLETE',
        householdCount: parseInt(householdCount) || 0,
        housingTenure,
        contactPhone,
        confirmationNumber,
        surveyData: typeof surveyData === 'string' ? JSON.parse(surveyData) : surveyData,
        completedAt: new Date().toISOString()
    };
    
    await docClient.send(new PutCommand({
        TableName: CENSUS_TABLE,
        Item: surveyRecord
    }));
    
    // Update address record with completion status
    if (params.addressId) {
        await docClient.send(new UpdateCommand({
            TableName: ADDRESS_TABLE,
            Key: { addressId: params.addressId },
            UpdateExpression: 'SET surveyStatus = :status, completedAt = :time, confirmationNumber = :conf',
            ExpressionAttributeValues: {
                ':status': status || 'COMPLETE',
                ':time': new Date().toISOString(),
                ':conf': confirmationNumber
            }
        }));
    }
    
    return {
        success: true,
        confirmationNumber,
        status: status || 'COMPLETE',
        message: 'Survey saved successfully'
    };
}

/**
 * Schedule a callback
 */
async function scheduleCallback(event) {
    const params = event.Details?.Parameters || event;
    const { caseId, phoneNumber, callbackDate, callbackTime, preferredLanguage } = params;
    
    const callbackDateTime = `${callbackDate} ${callbackTime}`;
    
    const callbackRecord = {
        caseId,
        timestamp: `CALLBACK#${new Date().toISOString()}`,
        type: 'CALLBACK_SCHEDULED',
        phoneNumber,
        callbackDateTime,
        preferredLanguage: preferredLanguage || 'en-US',
        scheduledAt: new Date().toISOString(),
        status: 'PENDING'
    };
    
    await docClient.send(new PutCommand({
        TableName: CENSUS_TABLE,
        Item: callbackRecord
    }));
    
    return {
        success: true,
        callbackScheduled: true,
        callbackDateTime,
        phoneNumber,
        message: `Callback scheduled for ${callbackDateTime}`
    };
}

/**
 * Process AI agent response and determine next action
 */
async function processAIResponse(event) {
    const params = event.Details?.Parameters || event;
    const { aiResponse, currentState, collectedData } = params;
    
    // Analyze the AI response to determine next action
    let nextAction = 'CONTINUE';
    
    const lowerResponse = (aiResponse || '').toLowerCase();
    
    if (lowerResponse.includes('survey complete') || 
        lowerResponse.includes('thank you for completing') ||
        lowerResponse.includes('confirmation number')) {
        nextAction = 'COMPLETE';
    } else if (lowerResponse.includes('transfer') || 
               lowerResponse.includes('live agent') ||
               lowerResponse.includes('human representative')) {
        nextAction = 'ESCALATE';
    } else if (lowerResponse.includes('callback') || 
               lowerResponse.includes('call back') ||
               lowerResponse.includes('call you later')) {
        nextAction = 'CALLBACK';
    }
    
    return {
        aiAction: nextAction,
        aiResponse,
        currentState: currentState || 'IN_PROGRESS',
        collectedData
    };
}

/**
 * Generate a confirmation number
 */
async function generateConfirmationNumber(event) {
    const confirmationNumber = generateConfirmationCode();
    return {
        confirmationNumber,
        generatedAt: new Date().toISOString()
    };
}

/**
 * Helper function to generate confirmation code
 */
function generateConfirmationCode() {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `CEN-${timestamp}-${random}`;
}

/**
 * Helper function to calculate age from date of birth
 */
function calculateAge(dateOfBirth, referenceDate = '2020-04-01') {
    const dob = new Date(dateOfBirth);
    const ref = new Date(referenceDate);
    let age = ref.getFullYear() - dob.getFullYear();
    const monthDiff = ref.getMonth() - dob.getMonth();
    
    if (monthDiff < 0 || (monthDiff === 0 && ref.getDate() < dob.getDate())) {
        age--;
    }
    
    return age;
}

/**
 * Validate census data before saving
 */
function validateCensusData(data) {
    const errors = [];
    
    if (!data.householdCount || data.householdCount < 1) {
        errors.push('Household count must be at least 1');
    }
    
    if (data.persons) {
        for (const person of data.persons) {
            if (!person.firstName || !person.lastName) {
                errors.push(`Person ${person.personNumber}: Name is required`);
            }
            if (!person.sex) {
                errors.push(`Person ${person.personNumber}: Sex is required`);
            }
            if (!person.dateOfBirth && !person.age) {
                errors.push(`Person ${person.personNumber}: Date of birth or age is required`);
            }
            if (!person.race || person.race.length === 0) {
                errors.push(`Person ${person.personNumber}: Race is required`);
            }
        }
    }
    
    return {
        isValid: errors.length === 0,
        errors
    };
}

module.exports = { handler: exports.handler };
