/**
 * VALIDATION UTILITIES - SHARED LAYER
 * 
 * WHAT: Common utilities shared across all validation Lambda functions.
 * 
 * WHY: Reduces code duplication and ensures consistent behavior across
 *      all validation components.
 */

const { 
  CloudWatchClient, 
  PutMetricDataCommand 
} = require('@aws-sdk/client-cloudwatch');

const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand
} = require('@aws-sdk/client-s3');

const {
  SNSClient,
  PublishCommand
} = require('@aws-sdk/client-sns');

// Initialize clients
const cloudwatch = new CloudWatchClient({});
const s3 = new S3Client({});
const sns = new SNSClient({});

/**
 * Publish custom metric to CloudWatch
 */
async function publishMetric(metricName, value, unit = 'Count', dimensions = {}) {
  const environment = process.env.ENVIRONMENT || 'development';
  
  const metricDimensions = [
    { Name: 'Environment', Value: environment },
    ...Object.entries(dimensions).map(([name, value]) => ({ Name: name, Value: value }))
  ];
  
  const command = new PutMetricDataCommand({
    Namespace: 'CCaaS/Validation',
    MetricData: [{
      MetricName: metricName,
      Value: value,
      Unit: unit,
      Dimensions: metricDimensions,
      Timestamp: new Date()
    }]
  });
  
  await cloudwatch.send(command);
}

/**
 * Save JSON data to S3
 */
async function saveToS3(bucket, key, data) {
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: JSON.stringify(data, null, 2),
    ContentType: 'application/json'
  });
  
  await s3.send(command);
  return `s3://${bucket}/${key}`;
}

/**
 * Save HTML report to S3
 */
async function saveHtmlToS3(bucket, key, html) {
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: html,
    ContentType: 'text/html'
  });
  
  await s3.send(command);
  return `s3://${bucket}/${key}`;
}

/**
 * Get JSON data from S3
 */
async function getFromS3(bucket, key) {
  const command = new GetObjectCommand({
    Bucket: bucket,
    Key: key
  });
  
  const response = await s3.send(command);
  const body = await response.Body.transformToString();
  return JSON.parse(body);
}

/**
 * Send SNS notification
 */
async function sendNotification(topicArn, subject, message) {
  if (!topicArn) {
    console.log('No SNS topic configured, skipping notification');
    return;
  }
  
  const command = new PublishCommand({
    TopicArn: topicArn,
    Subject: subject,
    Message: typeof message === 'string' ? message : JSON.stringify(message, null, 2)
  });
  
  await sns.send(command);
}

/**
 * Calculate test statistics
 */
function calculateStats(results) {
  const passed = results.filter(r => r.status === 'PASSED').length;
  const failed = results.filter(r => r.status === 'FAILED').length;
  const skipped = results.filter(r => r.status === 'SKIPPED').length;
  const total = results.length;
  
  return {
    passed,
    failed,
    skipped,
    total,
    passRate: total > 0 ? (passed / total * 100).toFixed(2) : 0,
    overallStatus: failed > 0 ? 'FAILED' : 'PASSED'
  };
}

/**
 * Format duration for display
 */
function formatDuration(ms) {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(2)}s`;
  return `${(ms / 60000).toFixed(2)}m`;
}

/**
 * Generate unique test run ID
 */
function generateRunId() {
  const now = new Date();
  const timestamp = now.toISOString().replace(/[:.]/g, '-');
  const random = Math.random().toString(36).substring(2, 8);
  return `run-${timestamp}-${random}`;
}

/**
 * Create test result object
 */
function createTestResult(testName, status, duration, details = {}) {
  return {
    testName,
    status, // PASSED, FAILED, SKIPPED
    duration,
    timestamp: new Date().toISOString(),
    ...details
  };
}

/**
 * Retry async function with exponential backoff
 */
async function retry(fn, maxAttempts = 3, baseDelayMs = 1000) {
  let lastError;
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt < maxAttempts) {
        const delay = baseDelayMs * Math.pow(2, attempt - 1);
        console.log(`Attempt ${attempt} failed, retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }
  
  throw lastError;
}

/**
 * Calculate percentile from array of numbers
 */
function percentile(arr, p) {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const index = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
}

/**
 * Generate HTML report template
 */
function generateHtmlReport(title, summary, sections) {
  const statusColor = summary.overallStatus === 'PASSED' ? '#28a745' : '#dc3545';
  
  return `
<!DOCTYPE html>
<html>
<head>
  <title>${title}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
    .header h1 { margin: 0 0 10px 0; }
    .header .subtitle { opacity: 0.8; }
    .status-badge { display: inline-block; padding: 8px 16px; border-radius: 20px; font-weight: bold; background: ${statusColor}; color: white; }
    .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
    .summary-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); text-align: center; }
    .summary-card .value { font-size: 36px; font-weight: bold; color: #1a1a2e; }
    .summary-card .label { color: #666; margin-top: 5px; }
    .section { background: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .section h2 { margin-top: 0; color: #1a1a2e; border-bottom: 2px solid #eee; padding-bottom: 10px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 12px; text-align: left; border-bottom: 1px solid #eee; }
    th { background: #f8f9fa; font-weight: 600; }
    .passed { color: #28a745; }
    .failed { color: #dc3545; }
    .skipped { color: #ffc107; }
    .footer { text-align: center; color: #666; padding: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🏛️ ${title}</h1>
      <div class="subtitle">Government CCaaS Validation Report</div>
      <div style="margin-top: 15px;">
        <span class="status-badge">${summary.overallStatus}</span>
        <span style="margin-left: 15px; opacity: 0.8;">Generated: ${new Date().toISOString()}</span>
      </div>
    </div>
    
    <div class="summary-grid">
      <div class="summary-card">
        <div class="value">${summary.total}</div>
        <div class="label">Total Tests</div>
      </div>
      <div class="summary-card">
        <div class="value passed">${summary.passed}</div>
        <div class="label">Passed</div>
      </div>
      <div class="summary-card">
        <div class="value failed">${summary.failed}</div>
        <div class="label">Failed</div>
      </div>
      <div class="summary-card">
        <div class="value">${summary.passRate}%</div>
        <div class="label">Pass Rate</div>
      </div>
    </div>
    
    ${sections.map(section => `
    <div class="section">
      <h2>${section.title}</h2>
      ${section.content}
    </div>
    `).join('')}
    
    <div class="footer">
      <p>Government CCaaS in a Box - Validation Module</p>
    </div>
  </div>
</body>
</html>
  `;
}

module.exports = {
  publishMetric,
  saveToS3,
  saveHtmlToS3,
  getFromS3,
  sendNotification,
  calculateStats,
  formatDuration,
  generateRunId,
  createTestResult,
  retry,
  percentile,
  generateHtmlReport
};
