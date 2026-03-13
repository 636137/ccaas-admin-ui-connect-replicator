/**
 * VALIDATION REPORT GENERATOR
 * 
 * WHAT: Generates comprehensive validation reports from test results.
 * 
 * WHY: Provides human-readable reports for stakeholders showing validation
 *      status, compliance posture, and AI quality metrics.
 * 
 * OUTPUTS:
 *   - JSON detailed report
 *   - HTML visual report
 *   - CloudWatch dashboard-ready metrics
 */

const {
  S3Client,
  ListObjectsV2Command
} = require('@aws-sdk/client-s3');

const {
  SNSClient,
  PublishCommand
} = require('@aws-sdk/client-sns');

// Import shared utilities
const utils = require('/opt/nodejs/validation-utils');

// Initialize clients
const s3 = new S3Client({});
const sns = new SNSClient({});

/**
 * Main handler
 */
exports.handler = async (event) => {
  console.log('Report Generator - Event:', JSON.stringify(event));
  
  const runId = event.runId || event.orchestratorResults?.runId || utils.generateRunId();
  const startTime = Date.now();
  
  const config = {
    reportBucket: process.env.REPORT_BUCKET,
    snsTopicArn: process.env.SNS_TOPIC_ARN,
    environment: process.env.ENVIRONMENT
  };
  
  // Collect all results from the validation run
  const orchestratorResults = event.orchestratorResults || {};
  const aiValidatorResults = event.aiValidatorResults || {};
  const securityValidatorResults = event.securityValidatorResults || {};
  
  // Aggregate all test results
  const allTests = [
    ...(orchestratorResults.tests || []),
    ...(aiValidatorResults.tests || []),
    ...(securityValidatorResults.tests || [])
  ];
  
  // Calculate overall summary
  const summary = utils.calculateStats(allTests);
  
  // Build comprehensive report
  const report = {
    metadata: {
      runId,
      generatedAt: new Date().toISOString(),
      environment: config.environment,
      reportVersion: '1.0.0'
    },
    summary: {
      ...summary,
      duration: (orchestratorResults.duration || 0) + 
                (aiValidatorResults.duration || 0) +
                (securityValidatorResults.duration || 0)
    },
    sections: {
      functional: {
        status: orchestratorResults.summary?.overallStatus || 'NOT_RUN',
        stats: orchestratorResults.summary || {},
        tests: orchestratorResults.tests || []
      },
      ai: {
        status: aiValidatorResults.summary?.overallStatus || 'NOT_RUN',
        stats: aiValidatorResults.summary || {},
        metrics: aiValidatorResults.aiMetrics || {},
        tests: aiValidatorResults.tests || []
      },
      security: {
        status: securityValidatorResults.summary?.overallStatus || 'NOT_RUN',
        stats: securityValidatorResults.summary || {},
        tests: securityValidatorResults.tests || []
      }
    },
    recommendations: generateRecommendations(orchestratorResults, aiValidatorResults, securityValidatorResults)
  };
  
  try {
    // Save JSON report
    const jsonKey = `results/${runId}/validation-report.json`;
    await utils.saveToS3(config.reportBucket, jsonKey, report);
    
    // Generate and save HTML report
    const htmlReport = generateHtmlReport(report);
    const htmlKey = `results/${runId}/validation-report.html`;
    await utils.saveHtmlToS3(config.reportBucket, htmlKey, htmlReport);
    
    // Save latest report pointer
    await utils.saveToS3(config.reportBucket, 'latest/report.json', {
      runId,
      timestamp: report.metadata.generatedAt,
      jsonReport: `s3://${config.reportBucket}/${jsonKey}`,
      htmlReport: `s3://${config.reportBucket}/${htmlKey}`,
      summary: report.summary
    });
    
    // Prepare response
    const response = {
      runId,
      generatedAt: report.metadata.generatedAt,
      summary: report.summary,
      reports: {
        json: `s3://${config.reportBucket}/${jsonKey}`,
        html: `s3://${config.reportBucket}/${htmlKey}`
      },
      recommendationCount: report.recommendations.length
    };
    
    console.log('Report generated:', response);
    return response;
    
  } catch (error) {
    console.error('Report generation error:', error);
    throw error;
  }
};

/**
 * Generate actionable recommendations based on test results
 */
function generateRecommendations(orchestrator, ai, security) {
  const recommendations = [];
  
  // Functional test recommendations
  if (orchestrator.summary?.failed > 0) {
    const failedTests = (orchestrator.tests || []).filter(t => t.status === 'FAILED');
    
    if (failedTests.some(t => t.testName.includes('connect'))) {
      recommendations.push({
        category: 'Infrastructure',
        severity: 'HIGH',
        title: 'Amazon Connect Issues Detected',
        description: 'One or more Amazon Connect validation tests failed. Review Connect instance configuration and contact flow status.',
        action: 'Check Connect console for instance health, verify contact flows are published, and ensure IAM permissions are correct.'
      });
    }
    
    if (failedTests.some(t => t.testName.includes('lex'))) {
      recommendations.push({
        category: 'NLU',
        severity: 'HIGH',
        title: 'Lex Bot Issues Detected',
        description: 'Lex bot validation tests failed. The bot may not be properly deployed or configured.',
        action: 'Verify Lex bot status, check bot alias deployment, and ensure locale is correctly configured.'
      });
    }
    
    if (failedTests.some(t => t.testName.includes('lambda'))) {
      recommendations.push({
        category: 'Compute',
        severity: 'MEDIUM',
        title: 'Lambda Function Issues',
        description: 'One or more Lambda functions are not in Active state.',
        action: 'Check Lambda console for function errors, verify IAM roles, and review CloudWatch logs.'
      });
    }
  }
  
  // AI quality recommendations
  if (ai.aiMetrics) {
    if (!ai.aiMetrics.meetsAccuracyThreshold) {
      recommendations.push({
        category: 'AI Quality',
        severity: 'HIGH',
        title: 'AI Accuracy Below Threshold',
        description: `Current accuracy (${ai.aiMetrics.intentAccuracy}%) is below the required threshold.`,
        action: 'Review Lex bot training data, add more utterances for underperforming intents, and consider retraining the bot.'
      });
    }
    
    if (!ai.aiMetrics.meetsLatencyThreshold) {
      recommendations.push({
        category: 'Performance',
        severity: 'MEDIUM',
        title: 'AI Response Latency High',
        description: `Average latency (${ai.aiMetrics.averageLatency}ms) exceeds threshold.`,
        action: 'Consider using provisioned throughput for Bedrock, optimize Lambda cold starts, or review agent complexity.'
      });
    }
    
    const guardrailEffectiveness = parseFloat(ai.aiMetrics.guardrailEffectiveness);
    if (!isNaN(guardrailEffectiveness) && guardrailEffectiveness < 90) {
      recommendations.push({
        category: 'Security',
        severity: 'HIGH',
        title: 'Guardrail Effectiveness Low',
        description: `Guardrails are only ${ai.aiMetrics.guardrailEffectiveness}% effective at blocking harmful content.`,
        action: 'Review guardrail configuration, add additional content filters, and test with more edge cases.'
      });
    }
  }
  
  // Security recommendations
  if (security.summary?.failed > 0) {
    recommendations.push({
      category: 'Compliance',
      severity: 'CRITICAL',
      title: 'Security Validation Failed',
      description: 'One or more security/compliance checks failed.',
      action: 'Review AWS Config rules, address non-compliant resources, and verify FedRAMP conformance pack status.'
    });
  }
  
  // Add general recommendations if everything passed
  if (recommendations.length === 0) {
    recommendations.push({
      category: 'General',
      severity: 'INFO',
      title: 'All Validations Passed',
      description: 'All infrastructure, AI, and security validations completed successfully.',
      action: 'Continue monitoring with scheduled validations. Consider increasing test coverage.'
    });
  }
  
  return recommendations;
}

/**
 * Generate HTML report
 */
function generateHtmlReport(report) {
  const { metadata, summary, sections, recommendations } = report;
  
  // Build test results table
  const buildTestTable = (tests) => {
    if (!tests || tests.length === 0) return '<p>No tests run</p>';
    
    return `
      <table>
        <thead>
          <tr>
            <th>Test Name</th>
            <th>Status</th>
            <th>Duration</th>
            <th>Details</th>
          </tr>
        </thead>
        <tbody>
          ${tests.map(test => `
            <tr>
              <td>${test.testName}</td>
              <td class="${test.status.toLowerCase()}">${test.status}</td>
              <td>${utils.formatDuration(test.duration)}</td>
              <td>${formatTestDetails(test)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  };
  
  // Format test details for display
  const formatTestDetails = (test) => {
    const details = { ...test };
    delete details.testName;
    delete details.status;
    delete details.duration;
    delete details.timestamp;
    
    const entries = Object.entries(details).slice(0, 3);
    return entries.map(([key, value]) => {
      const displayValue = typeof value === 'object' ? JSON.stringify(value).substring(0, 50) : String(value).substring(0, 50);
      return `<small><strong>${key}:</strong> ${displayValue}</small>`;
    }).join('<br>');
  };
  
  // Build recommendations section
  const buildRecommendations = () => {
    return recommendations.map(rec => {
      const severityColors = {
        CRITICAL: '#dc3545',
        HIGH: '#fd7e14',
        MEDIUM: '#ffc107',
        LOW: '#28a745',
        INFO: '#17a2b8'
      };
      const color = severityColors[rec.severity] || '#6c757d';
      
      return `
        <div style="border-left: 4px solid ${color}; padding: 15px; margin: 10px 0; background: #f8f9fa; border-radius: 0 5px 5px 0;">
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <strong>${rec.title}</strong>
            <span style="background: ${color}; color: white; padding: 2px 8px; border-radius: 3px; font-size: 12px;">${rec.severity}</span>
          </div>
          <p style="margin: 10px 0; color: #666;">${rec.description}</p>
          <p style="margin: 0; color: #333;"><strong>Action:</strong> ${rec.action}</p>
        </div>
      `;
    }).join('');
  };
  
  // Build AI metrics section
  const buildAIMetrics = () => {
    const metrics = sections.ai.metrics;
    if (!metrics || Object.keys(metrics).length === 0) {
      return '<p>No AI metrics available</p>';
    }
    
    return `
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin: 15px 0;">
        <div style="background: #e9ecef; padding: 15px; border-radius: 5px; text-align: center;">
          <div style="font-size: 24px; font-weight: bold; color: ${metrics.meetsAccuracyThreshold ? '#28a745' : '#dc3545'};">
            ${metrics.intentAccuracy}%
          </div>
          <div style="color: #666;">Intent Accuracy</div>
        </div>
        <div style="background: #e9ecef; padding: 15px; border-radius: 5px; text-align: center;">
          <div style="font-size: 24px; font-weight: bold; color: ${metrics.meetsLatencyThreshold ? '#28a745' : '#dc3545'};">
            ${metrics.averageLatency}ms
          </div>
          <div style="color: #666;">Avg Latency</div>
        </div>
        <div style="background: #e9ecef; padding: 15px; border-radius: 5px; text-align: center;">
          <div style="font-size: 24px; font-weight: bold;">${metrics.p95Latency}ms</div>
          <div style="color: #666;">P95 Latency</div>
        </div>
        <div style="background: #e9ecef; padding: 15px; border-radius: 5px; text-align: center;">
          <div style="font-size: 24px; font-weight: bold;">${metrics.guardrailEffectiveness}%</div>
          <div style="color: #666;">Guardrail Block Rate</div>
        </div>
      </div>
    `;
  };
  
  // Generate HTML sections
  const htmlSections = [
    {
      title: '📋 Functional Tests',
      content: `
        <p><strong>Status:</strong> <span class="${sections.functional.status.toLowerCase()}">${sections.functional.status}</span></p>
        <p>Passed: ${sections.functional.stats.passed || 0} | Failed: ${sections.functional.stats.failed || 0} | Skipped: ${sections.functional.stats.skipped || 0}</p>
        ${buildTestTable(sections.functional.tests)}
      `
    },
    {
      title: '🤖 AI Validation',
      content: `
        <p><strong>Status:</strong> <span class="${sections.ai.status.toLowerCase()}">${sections.ai.status}</span></p>
        ${buildAIMetrics()}
        ${buildTestTable(sections.ai.tests)}
      `
    },
    {
      title: '🔒 Security & Compliance',
      content: `
        <p><strong>Status:</strong> <span class="${sections.security.status.toLowerCase()}">${sections.security.status}</span></p>
        ${buildTestTable(sections.security.tests)}
      `
    },
    {
      title: '💡 Recommendations',
      content: buildRecommendations()
    }
  ];
  
  return utils.generateHtmlReport(
    `Validation Report - ${metadata.runId}`,
    summary,
    htmlSections
  );
}
