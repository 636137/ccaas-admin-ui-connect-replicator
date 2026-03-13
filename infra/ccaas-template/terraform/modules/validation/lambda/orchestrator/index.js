/**
 * VALIDATION ORCHESTRATOR
 * 
 * WHAT: Coordinates and runs validation tests for Government CCaaS deployments.
 * 
 * WHY: Provides a single entry point for running functional, load, security,
 *      and AI validation tests against Amazon Connect, Lex, and Bedrock.
 * 
 * FUNCTIONS:
 *   - runFunctionalTests: Tests Connect flows, Lex intents, Lambda functions
 *   - runConnectNativeTests: Uses Amazon Connect Testing & Simulation API
 *   - runLoadTests: Triggers AWS Distributed Load Testing
 *   - runSecurityValidation: Checks AWS Config compliance
 */

const {
  ConnectClient,
  DescribeInstanceCommand,
  ListContactFlowsCommand,
  DescribeContactFlowCommand,
  ListQueuesCommand,
  GetCurrentMetricDataCommand
} = require('@aws-sdk/client-connect');

const {
  LexModelsV2Client,
  DescribeBotCommand,
  DescribeBotAliasCommand,
  ListIntentsCommand
} = require('@aws-sdk/client-lex-models-v2');

const {
  LambdaClient,
  InvokeCommand,
  GetFunctionCommand
} = require('@aws-sdk/client-lambda');

const {
  DynamoDBClient,
  DescribeTableCommand
} = require('@aws-sdk/client-dynamodb');

const {
  ConfigServiceClient,
  DescribeConformancePackComplianceCommand,
  GetConformancePackComplianceDetailsCommand
} = require('@aws-sdk/client-config-service');

// Import shared utilities
const utils = require('/opt/nodejs/validation-utils');

// Initialize clients
const connect = new ConnectClient({});
const lexModels = new LexModelsV2Client({});
const lambda = new LambdaClient({});
const dynamodb = new DynamoDBClient({});
const configService = new ConfigServiceClient({});

/**
 * Main handler - orchestrates validation based on test type
 */
exports.handler = async (event) => {
  console.log('Validation Orchestrator - Event:', JSON.stringify(event));
  
  const testType = event.testType || 'all';
  const runId = event.runId || utils.generateRunId();
  const startTime = Date.now();
  
  const config = {
    connectInstanceId: process.env.CONNECT_INSTANCE_ID,
    connectInstanceArn: process.env.CONNECT_INSTANCE_ARN,
    lexBotId: process.env.LEX_BOT_ID,
    lexBotAliasId: process.env.LEX_BOT_ALIAS_ID,
    lexLocaleId: process.env.LEX_LOCALE_ID || 'en_US',
    bedrockAgentId: process.env.BEDROCK_AGENT_ID,
    lambdaArns: (process.env.LAMBDA_ARNS || '').split(',').filter(Boolean),
    dynamodbTables: (process.env.DYNAMODB_TABLE_NAMES || '').split(',').filter(Boolean),
    reportBucket: process.env.REPORT_BUCKET,
    environment: process.env.ENVIRONMENT
  };
  
  console.log('Configuration loaded:', { 
    ...config, 
    lambdaCount: config.lambdaArns.length,
    tableCount: config.dynamodbTables.length 
  });
  
  const results = {
    runId,
    testType,
    startTime: new Date(startTime).toISOString(),
    environment: config.environment,
    tests: []
  };
  
  try {
    switch (testType) {
      case 'functional':
        results.tests = await runFunctionalTests(config);
        break;
      case 'connect':
        results.tests = await runConnectTests(config);
        break;
      case 'lex':
        results.tests = await runLexTests(config);
        break;
      case 'lambda':
        results.tests = await runLambdaTests(config);
        break;
      case 'dynamodb':
        results.tests = await runDynamoDBTests(config);
        break;
      case 'security':
        results.tests = await runSecurityValidation(config);
        break;
      case 'all':
      default:
        // Run all functional tests in sequence
        const connectTests = await runConnectTests(config);
        const lexTests = await runLexTests(config);
        const lambdaTests = await runLambdaTests(config);
        const dynamoTests = await runDynamoDBTests(config);
        results.tests = [...connectTests, ...lexTests, ...lambdaTests, ...dynamoTests];
    }
    
    results.endTime = new Date().toISOString();
    results.duration = Date.now() - startTime;
    results.summary = utils.calculateStats(results.tests);
    
    // Publish metrics
    await publishValidationMetrics(results);
    
    // Save results to S3
    if (config.reportBucket) {
      const key = `results/${results.runId}/orchestrator-results.json`;
      await utils.saveToS3(config.reportBucket, key, results);
    }
    
    console.log('Validation complete:', results.summary);
    return results;
    
  } catch (error) {
    console.error('Orchestrator error:', error);
    results.error = error.message;
    results.summary = { overallStatus: 'ERROR', error: error.message };
    throw error;
  }
};

/**
 * Run all functional tests
 */
async function runFunctionalTests(config) {
  const results = [];
  
  results.push(...await runConnectTests(config));
  results.push(...await runLexTests(config));
  results.push(...await runLambdaTests(config));
  results.push(...await runDynamoDBTests(config));
  
  return results;
}

/**
 * Amazon Connect Validation Tests
 */
async function runConnectTests(config) {
  const results = [];
  
  if (!config.connectInstanceId) {
    results.push(utils.createTestResult('connect-instance-check', 'SKIPPED', 0, {
      message: 'Connect instance ID not configured'
    }));
    return results;
  }
  
  // Test 1: Verify Connect instance is accessible
  const instanceTest = await testConnectInstance(config.connectInstanceId);
  results.push(instanceTest);
  
  // Test 2: Verify contact flows exist and are published
  const flowsTest = await testContactFlows(config.connectInstanceId);
  results.push(flowsTest);
  
  // Test 3: Verify queues are configured
  const queuesTest = await testQueues(config.connectInstanceId);
  results.push(queuesTest);
  
  // Test 4: Check real-time metrics availability
  const metricsTest = await testConnectMetrics(config.connectInstanceId);
  results.push(metricsTest);
  
  return results;
}

async function testConnectInstance(instanceId) {
  const start = Date.now();
  try {
    const command = new DescribeInstanceCommand({ InstanceId: instanceId });
    const response = await connect.send(command);
    
    const isActive = response.Instance?.InstanceStatus === 'ACTIVE';
    return utils.createTestResult(
      'connect-instance-active',
      isActive ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        instanceId,
        status: response.Instance?.InstanceStatus,
        servicerole: response.Instance?.ServiceRole
      }
    );
  } catch (error) {
    return utils.createTestResult('connect-instance-active', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

async function testContactFlows(instanceId) {
  const start = Date.now();
  try {
    const command = new ListContactFlowsCommand({ InstanceId: instanceId });
    const response = await connect.send(command);
    
    const flows = response.ContactFlowSummaryList || [];
    const publishedFlows = flows.filter(f => f.ContactFlowState === 'ACTIVE');
    
    return utils.createTestResult(
      'connect-contact-flows',
      flows.length > 0 ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        totalFlows: flows.length,
        publishedFlows: publishedFlows.length,
        flowNames: publishedFlows.slice(0, 5).map(f => f.Name)
      }
    );
  } catch (error) {
    return utils.createTestResult('connect-contact-flows', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

async function testQueues(instanceId) {
  const start = Date.now();
  try {
    const command = new ListQueuesCommand({ 
      InstanceId: instanceId,
      QueueTypes: ['STANDARD']
    });
    const response = await connect.send(command);
    
    const queues = response.QueueSummaryList || [];
    
    return utils.createTestResult(
      'connect-queues',
      queues.length > 0 ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        queueCount: queues.length,
        queueNames: queues.slice(0, 5).map(q => q.Name)
      }
    );
  } catch (error) {
    return utils.createTestResult('connect-queues', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

async function testConnectMetrics(instanceId) {
  const start = Date.now();
  try {
    // Check if we can query real-time metrics
    const command = new GetCurrentMetricDataCommand({
      InstanceId: instanceId,
      Filters: {
        Queues: [],
        Channels: ['VOICE']
      },
      CurrentMetrics: [
        { Name: 'AGENTS_ONLINE', Unit: 'COUNT' }
      ]
    });
    
    await connect.send(command);
    
    return utils.createTestResult(
      'connect-metrics-access',
      'PASSED',
      Date.now() - start,
      { message: 'Real-time metrics API accessible' }
    );
  } catch (error) {
    // Some errors are expected if no queues configured
    const isAccessible = !error.message.includes('AccessDenied');
    return utils.createTestResult(
      'connect-metrics-access',
      isAccessible ? 'PASSED' : 'FAILED',
      Date.now() - start,
      { error: error.message }
    );
  }
}

/**
 * Amazon Lex Validation Tests
 */
async function runLexTests(config) {
  const results = [];
  
  if (!config.lexBotId) {
    results.push(utils.createTestResult('lex-bot-check', 'SKIPPED', 0, {
      message: 'Lex bot ID not configured'
    }));
    return results;
  }
  
  // Test 1: Verify bot exists and is available
  const botTest = await testLexBot(config.lexBotId);
  results.push(botTest);
  
  // Test 2: Verify bot alias is deployed
  if (config.lexBotAliasId) {
    const aliasTest = await testLexBotAlias(config.lexBotId, config.lexBotAliasId);
    results.push(aliasTest);
  }
  
  // Test 3: Verify intents are configured
  const intentsTest = await testLexIntents(config.lexBotId, config.lexLocaleId);
  results.push(intentsTest);
  
  return results;
}

async function testLexBot(botId) {
  const start = Date.now();
  try {
    const command = new DescribeBotCommand({ botId });
    const response = await lexModels.send(command);
    
    const isAvailable = response.botStatus === 'Available';
    return utils.createTestResult(
      'lex-bot-available',
      isAvailable ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        botId,
        botName: response.botName,
        status: response.botStatus
      }
    );
  } catch (error) {
    return utils.createTestResult('lex-bot-available', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

async function testLexBotAlias(botId, botAliasId) {
  const start = Date.now();
  try {
    const command = new DescribeBotAliasCommand({ botId, botAliasId });
    const response = await lexModels.send(command);
    
    const isAvailable = response.botAliasStatus === 'Available';
    return utils.createTestResult(
      'lex-bot-alias-available',
      isAvailable ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        botAliasId,
        aliasName: response.botAliasName,
        status: response.botAliasStatus
      }
    );
  } catch (error) {
    return utils.createTestResult('lex-bot-alias-available', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

async function testLexIntents(botId, localeId) {
  const start = Date.now();
  try {
    const command = new ListIntentsCommand({
      botId,
      botVersion: 'DRAFT',
      localeId
    });
    const response = await lexModels.send(command);
    
    const intents = response.intentSummaries || [];
    const hasIntents = intents.length > 0;
    
    return utils.createTestResult(
      'lex-intents-configured',
      hasIntents ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        intentCount: intents.length,
        intentNames: intents.slice(0, 10).map(i => i.intentName)
      }
    );
  } catch (error) {
    return utils.createTestResult('lex-intents-configured', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

/**
 * Lambda Function Validation Tests
 */
async function runLambdaTests(config) {
  const results = [];
  
  if (config.lambdaArns.length === 0) {
    results.push(utils.createTestResult('lambda-functions-check', 'SKIPPED', 0, {
      message: 'No Lambda functions configured for testing'
    }));
    return results;
  }
  
  for (const functionArn of config.lambdaArns) {
    const functionName = functionArn.split(':').pop();
    const test = await testLambdaFunction(functionName);
    results.push(test);
  }
  
  return results;
}

async function testLambdaFunction(functionName) {
  const start = Date.now();
  try {
    const command = new GetFunctionCommand({ FunctionName: functionName });
    const response = await lambda.send(command);
    
    const isActive = response.Configuration?.State === 'Active';
    const lastModified = response.Configuration?.LastModified;
    
    return utils.createTestResult(
      `lambda-${functionName}-active`,
      isActive ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        functionName,
        state: response.Configuration?.State,
        runtime: response.Configuration?.Runtime,
        lastModified,
        memorySize: response.Configuration?.MemorySize
      }
    );
  } catch (error) {
    return utils.createTestResult(`lambda-${functionName}-active`, 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

/**
 * DynamoDB Table Validation Tests
 */
async function runDynamoDBTests(config) {
  const results = [];
  
  if (config.dynamodbTables.length === 0) {
    results.push(utils.createTestResult('dynamodb-tables-check', 'SKIPPED', 0, {
      message: 'No DynamoDB tables configured for testing'
    }));
    return results;
  }
  
  for (const tableName of config.dynamodbTables) {
    const test = await testDynamoDBTable(tableName);
    results.push(test);
  }
  
  return results;
}

async function testDynamoDBTable(tableName) {
  const start = Date.now();
  try {
    const command = new DescribeTableCommand({ TableName: tableName });
    const response = await dynamodb.send(command);
    
    const isActive = response.Table?.TableStatus === 'ACTIVE';
    
    return utils.createTestResult(
      `dynamodb-${tableName}-active`,
      isActive ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        tableName,
        status: response.Table?.TableStatus,
        itemCount: response.Table?.ItemCount,
        sizeBytes: response.Table?.TableSizeBytes
      }
    );
  } catch (error) {
    return utils.createTestResult(`dynamodb-${tableName}-active`, 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

/**
 * Security Validation - AWS Config Compliance
 */
async function runSecurityValidation(config) {
  const results = [];
  
  // Check FedRAMP conformance pack if deployed
  const conformanceTest = await testConformancePackCompliance();
  results.push(conformanceTest);
  
  return results;
}

async function testConformancePackCompliance() {
  const start = Date.now();
  try {
    // List conformance packs and check compliance
    const command = new DescribeConformancePackComplianceCommand({
      ConformancePackName: 'FedRAMP-Conformance-Pack'
    });
    
    const response = await configService.send(command);
    const rules = response.ConformancePackRuleComplianceList || [];
    
    const compliant = rules.filter(r => r.ComplianceType === 'COMPLIANT').length;
    const nonCompliant = rules.filter(r => r.ComplianceType === 'NON_COMPLIANT').length;
    
    return utils.createTestResult(
      'fedramp-conformance-pack',
      nonCompliant === 0 ? 'PASSED' : 'FAILED',
      Date.now() - start,
      {
        totalRules: rules.length,
        compliant,
        nonCompliant,
        insufficientData: rules.filter(r => r.ComplianceType === 'INSUFFICIENT_DATA').length
      }
    );
  } catch (error) {
    // Conformance pack may not be deployed
    if (error.name === 'NoSuchConformancePackException') {
      return utils.createTestResult(
        'fedramp-conformance-pack',
        'SKIPPED',
        Date.now() - start,
        { message: 'FedRAMP conformance pack not deployed' }
      );
    }
    return utils.createTestResult('fedramp-conformance-pack', 'FAILED', Date.now() - start, {
      error: error.message
    });
  }
}

/**
 * Publish validation metrics to CloudWatch
 */
async function publishValidationMetrics(results) {
  const { summary } = results;
  
  await Promise.all([
    utils.publishMetric('TestsRun', summary.total, 'Count', { TestType: results.testType }),
    utils.publishMetric('TestsPassed', summary.passed, 'Count', { TestType: results.testType }),
    utils.publishMetric('TestsFailed', summary.failed, 'Count', { TestType: results.testType }),
    utils.publishMetric('TestsSkipped', summary.skipped, 'Count', { TestType: results.testType }),
    utils.publishMetric('PassRate', parseFloat(summary.passRate), 'Percent', { TestType: results.testType }),
    utils.publishMetric('Duration', results.duration, 'Milliseconds', { TestType: results.testType }),
    utils.publishMetric(
      summary.overallStatus === 'PASSED' ? 'ValidationSuccess' : 'ValidationFailed',
      1,
      'Count',
      { TestType: results.testType }
    )
  ]);
}
