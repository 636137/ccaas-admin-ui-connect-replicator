/**
 * Census Enumerator Lex Bot - Fulfillment Lambda
 * 
 * WHAT THIS DOES:
 * Handles ALL Lex bot interactions - dialog management, slot validation, and fulfillment.
 * Called by Lex whenever an intent needs processing or a slot needs validation.
 * 
 * HOW IT'S TRIGGERED:
 * Lex invokes this Lambda with event containing:
 * - sessionState.intent.name: Which intent is active
 * - sessionState.intent.slots: Current slot values
 * - sessionState.sessionAttributes: Persisted session data
 * 
 * KEY INTENTS HANDLED:
 * - WelcomeIntent: Consent to proceed
 * - VerifyAddressIntent: Confirm/correct address
 * - HouseholdCountIntent: Number of people
 * - CollectPersonInfoIntent: Demographics per person
 * - HousingInfoIntent: Own/rent status
 * - CompleteSurveyIntent: Finalize and generate confirmation
 * - ScheduleCallbackIntent: Schedule follow-up
 * - SpeakToAgentIntent: Escalate to human
 * 
 * DATA FLOW:
 * Lex → This Lambda → DynamoDB (CensusResponses table)
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { v4: uuidv4 } = require('uuid');

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

const CENSUS_TABLE = process.env.CENSUS_TABLE_NAME || 'CensusResponses';

/**
 * Main handler - routes to appropriate intent handler based on intent name
 */
exports.handler = async (event) => {
    console.log('Lex Event:', JSON.stringify(event, null, 2));
    
    const intentName = event.sessionState.intent.name;
    const slots = event.sessionState.intent.slots;
    const sessionAttributes = event.sessionState.sessionAttributes || {};
    
    // Route to appropriate handler based on which intent Lex detected
    switch (intentName) {
        case 'WelcomeIntent':
            return handleWelcomeIntent(event, slots, sessionAttributes);
        case 'VerifyAddressIntent':
            return handleVerifyAddressIntent(event, slots, sessionAttributes);
        case 'HouseholdCountIntent':
            return handleHouseholdCountIntent(event, slots, sessionAttributes);
        case 'CollectPersonInfoIntent':
            return handleCollectPersonInfoIntent(event, slots, sessionAttributes);
        case 'HousingInfoIntent':
            return handleHousingInfoIntent(event, slots, sessionAttributes);
        case 'CompleteSurveyIntent':
            return handleCompleteSurveyIntent(event, slots, sessionAttributes);
        case 'ScheduleCallbackIntent':
            return handleScheduleCallbackIntent(event, slots, sessionAttributes);
        case 'SpeakToAgentIntent':
            return handleSpeakToAgentIntent(event, slots, sessionAttributes);
        case 'RefuseSurveyIntent':
            return handleRefuseSurveyIntent(event, slots, sessionAttributes);
        case 'FallbackIntent':
            return handleFallbackIntent(event, sessionAttributes);
        default:
            // Unknown intent - let Lex handle it
            return buildResponse(event, 'Delegate', sessionAttributes);
    }
};

/**
 * WELCOME INTENT: Handle initial greeting and consent
 * If user says no, gracefully exit. If yes, initialize session and proceed.
 */
function handleWelcomeIntent(event, slots, sessionAttributes) {
    const consent = getSlotValue(slots, 'ConsentToProceed');
    
    if (consent && consent.toLowerCase() === 'no') {
        return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled', 
            "I understand. If you change your mind, you can complete your census online at census.gov or call 1-800-923-8282. Thank you for your time.");
    }
    
    // Initialize session for new survey - generate case ID and set initial state
    sessionAttributes.caseId = 'CASE-' + uuidv4().substring(0, 8);
    sessionAttributes.surveyStartTime = new Date().toISOString();
    sessionAttributes.currentPersonIndex = '0';
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        "Thank you for agreeing to participate. Let me verify your address on file.");
}

function handleVerifyAddressIntent(event, slots, sessionAttributes) {
    const addressConfirmed = getSlotValue(slots, 'AddressConfirmation');
    const isAdultResident = getSlotValue(slots, 'IsAdultResident');
    
    if (isAdultResident && isAdultResident.toLowerCase() === 'no') {
        return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
            "I understand. Unfortunately, I need to speak with an adult resident of this address to complete the survey. You can complete your census online at census.gov. Thank you for your time.");
    }
    
    if (addressConfirmed && addressConfirmed.toLowerCase() === 'no') {
        // Need to collect correct address
        sessionAttributes.addressCorrected = 'true';
        const street = getSlotValue(slots, 'StreetAddress');
        const city = getSlotValue(slots, 'City');
        const state = getSlotValue(slots, 'State');
        const zip = getSlotValue(slots, 'ZipCode');
        
        if (street) sessionAttributes.streetAddress = street;
        if (city) sessionAttributes.city = city;
        if (state) sessionAttributes.state = state;
        if (zip) sessionAttributes.zipCode = zip;
    }
    
    sessionAttributes.addressVerified = 'true';
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        "Thank you for confirming. Now let's move on to count the people in your household.");
}

function handleHouseholdCountIntent(event, slots, sessionAttributes) {
    const count = getSlotValue(slots, 'HouseholdCount');
    const confirmed = getSlotValue(slots, 'CountConfirmation');
    
    if (confirmed && confirmed.toLowerCase() === 'no') {
        // Re-elicit household count
        return buildElicitSlotResponse(event, 'HouseholdCount', sessionAttributes,
            "I'm sorry, let me ask again. How many people were living at this address on April 1st?");
    }
    
    if (count) {
        sessionAttributes.householdCount = count;
        sessionAttributes.currentPersonIndex = '1';
        sessionAttributes.personsCollected = '0';
    }
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        `Great, I'll collect information for ${count} people. Let's start with Person 1.`);
}

function handleCollectPersonInfoIntent(event, slots, sessionAttributes) {
    const firstName = getSlotValue(slots, 'FirstName');
    const lastName = getSlotValue(slots, 'LastName');
    const relationship = getSlotValue(slots, 'Relationship');
    const sex = getSlotValue(slots, 'Sex');
    const dob = getSlotValue(slots, 'DateOfBirth');
    const age = getSlotValue(slots, 'Age');
    const isHispanic = getSlotValue(slots, 'IsHispanicLatino');
    const hispanicOrigin = getSlotValue(slots, 'HispanicOrigin');
    const race = getSlotValue(slots, 'Race');
    const raceDetail = getSlotValue(slots, 'RaceDetail');
    
    const currentIndex = parseInt(sessionAttributes.currentPersonIndex || '1');
    const totalCount = parseInt(sessionAttributes.householdCount || '1');
    
    // Store person data in session
    const personKey = `person${currentIndex}`;
    sessionAttributes[`${personKey}_firstName`] = firstName;
    sessionAttributes[`${personKey}_lastName`] = lastName;
    sessionAttributes[`${personKey}_relationship`] = currentIndex === 1 ? 'Self' : relationship;
    sessionAttributes[`${personKey}_sex`] = sex;
    sessionAttributes[`${personKey}_dob`] = dob;
    sessionAttributes[`${personKey}_age`] = age;
    sessionAttributes[`${personKey}_isHispanic`] = isHispanic;
    sessionAttributes[`${personKey}_hispanicOrigin`] = hispanicOrigin;
    sessionAttributes[`${personKey}_race`] = race;
    sessionAttributes[`${personKey}_raceDetail`] = raceDetail;
    
    // Update counters
    sessionAttributes.personsCollected = currentIndex.toString();
    
    let responseMessage;
    
    if (currentIndex < totalCount) {
        // More people to collect
        sessionAttributes.currentPersonIndex = (currentIndex + 1).toString();
        responseMessage = `Thank you. I've recorded the information for ${firstName}. Now let's collect information for Person ${currentIndex + 1}.`;
    } else {
        // All people collected, move to housing
        responseMessage = `Thank you. I've recorded the information for ${firstName}. Now I have a couple questions about your housing.`;
    }
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled', responseMessage);
}

function handleHousingInfoIntent(event, slots, sessionAttributes) {
    const tenure = getSlotValue(slots, 'HousingTenure');
    const phone = getSlotValue(slots, 'PhoneNumber');
    
    sessionAttributes.housingTenure = tenure;
    if (phone) sessionAttributes.contactPhone = phone;
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        "Thank you for providing your housing information. We're almost done with the survey.");
}

async function handleCompleteSurveyIntent(event, slots, sessionAttributes) {
    // Generate confirmation number
    const confirmationNumber = generateConfirmationCode();
    sessionAttributes.confirmationNumber = confirmationNumber;
    sessionAttributes.surveyStatus = 'COMPLETE';
    sessionAttributes.completedAt = new Date().toISOString();
    
    // Save to DynamoDB
    try {
        await saveSurveyToDynamoDB(sessionAttributes);
    } catch (error) {
        console.error('Error saving survey:', error);
    }
    
    const householdCount = sessionAttributes.householdCount || '1';
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        `Thank you for completing the census survey! I've recorded information for ${householdCount} people at your address. Your confirmation number is ${confirmationNumber}. Please save this for your records. Thank you for doing your civic duty!`);
}

async function handleScheduleCallbackIntent(event, slots, sessionAttributes) {
    const callbackDate = getSlotValue(slots, 'CallbackDate');
    const callbackTime = getSlotValue(slots, 'CallbackTime');
    const callbackPhone = getSlotValue(slots, 'CallbackPhone');
    
    sessionAttributes.callbackScheduled = 'true';
    sessionAttributes.callbackDate = callbackDate;
    sessionAttributes.callbackTime = callbackTime;
    sessionAttributes.callbackPhone = callbackPhone;
    
    try {
        await saveCallbackToDynamoDB(sessionAttributes);
    } catch (error) {
        console.error('Error saving callback:', error);
    }
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        `I've scheduled a callback for ${callbackDate} at ${callbackTime}. We'll call you at ${callbackPhone}. Thank you for your time!`);
}

function handleSpeakToAgentIntent(event, slots, sessionAttributes) {
    sessionAttributes.escalationRequested = 'true';
    sessionAttributes.escalationReason = 'Customer requested live agent';
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        "I understand you'd like to speak with a census representative. Let me transfer you now. Please hold.",
        { action: 'TRANSFER_TO_AGENT' });
}

function handleRefuseSurveyIntent(event, slots, sessionAttributes) {
    sessionAttributes.surveyStatus = 'REFUSED';
    sessionAttributes.refusedAt = new Date().toISOString();
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        "I understand. If you change your mind, you can complete your census online at census.gov or call 1-800-923-8282. Thank you for your time.");
}

function handleFallbackIntent(event, sessionAttributes) {
    const retryCount = parseInt(sessionAttributes.fallbackRetryCount || '0') + 1;
    sessionAttributes.fallbackRetryCount = retryCount.toString();
    
    if (retryCount >= 3) {
        return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
            "I'm having trouble understanding. Let me connect you with a census representative who can assist you.");
    }
    
    return buildResponse(event, 'Close', sessionAttributes, 'Fulfilled',
        "I'm sorry, I didn't quite catch that. Could you please rephrase your response? You can also say 'help' for assistance.");
}

// Helper functions
function getSlotValue(slots, slotName) {
    if (!slots || !slots[slotName]) return null;
    
    const slot = slots[slotName];
    if (slot.value && slot.value.interpretedValue) {
        return slot.value.interpretedValue;
    }
    if (slot.value && slot.value.originalValue) {
        return slot.value.originalValue;
    }
    return null;
}

function buildResponse(event, dialogAction, sessionAttributes, state, message, additionalParams = {}) {
    const response = {
        sessionState: {
            dialogAction: {
                type: dialogAction
            },
            intent: {
                name: event.sessionState.intent.name,
                state: state || 'InProgress'
            },
            sessionAttributes: sessionAttributes
        }
    };
    
    if (message) {
        response.messages = [
            {
                contentType: 'PlainText',
                content: message
            }
        ];
    }
    
    // Add any additional parameters (like transfer action)
    if (additionalParams.action) {
        response.sessionState.sessionAttributes.requestedAction = additionalParams.action;
    }
    
    return response;
}

function buildElicitSlotResponse(event, slotName, sessionAttributes, message) {
    return {
        sessionState: {
            dialogAction: {
                type: 'ElicitSlot',
                slotToElicit: slotName
            },
            intent: {
                name: event.sessionState.intent.name,
                slots: event.sessionState.intent.slots,
                state: 'InProgress'
            },
            sessionAttributes: sessionAttributes
        },
        messages: [
            {
                contentType: 'PlainText',
                content: message
            }
        ]
    };
}

function generateConfirmationCode() {
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `CEN-${timestamp}-${random}`;
}

async function saveSurveyToDynamoDB(sessionAttributes) {
    const caseId = sessionAttributes.caseId;
    
    // Build persons array
    const persons = [];
    const totalCount = parseInt(sessionAttributes.householdCount || '0');
    
    for (let i = 1; i <= totalCount; i++) {
        const personKey = `person${i}`;
        persons.push({
            personNumber: i,
            firstName: sessionAttributes[`${personKey}_firstName`],
            lastName: sessionAttributes[`${personKey}_lastName`],
            relationship: sessionAttributes[`${personKey}_relationship`],
            sex: sessionAttributes[`${personKey}_sex`],
            dateOfBirth: sessionAttributes[`${personKey}_dob`],
            age: sessionAttributes[`${personKey}_age`],
            isHispanicLatino: sessionAttributes[`${personKey}_isHispanic`],
            hispanicOrigin: sessionAttributes[`${personKey}_hispanicOrigin`],
            race: sessionAttributes[`${personKey}_race`],
            raceDetail: sessionAttributes[`${personKey}_raceDetail`]
        });
    }
    
    await docClient.send(new PutCommand({
        TableName: CENSUS_TABLE,
        Item: {
            caseId: caseId,
            timestamp: sessionAttributes.completedAt,
            type: 'SURVEY_COMPLETE',
            status: 'COMPLETE',
            confirmationNumber: sessionAttributes.confirmationNumber,
            householdCount: totalCount,
            housingTenure: sessionAttributes.housingTenure,
            contactPhone: sessionAttributes.contactPhone,
            persons: persons,
            surveyStartTime: sessionAttributes.surveyStartTime,
            completedAt: sessionAttributes.completedAt
        }
    }));
}

async function saveCallbackToDynamoDB(sessionAttributes) {
    await docClient.send(new PutCommand({
        TableName: CENSUS_TABLE,
        Item: {
            caseId: sessionAttributes.caseId || 'CALLBACK-' + uuidv4().substring(0, 8),
            timestamp: new Date().toISOString(),
            type: 'CALLBACK_SCHEDULED',
            status: 'PENDING',
            callbackDate: sessionAttributes.callbackDate,
            callbackTime: sessionAttributes.callbackTime,
            callbackPhone: sessionAttributes.callbackPhone
        }
    }));
}

module.exports = { handler: exports.handler };
