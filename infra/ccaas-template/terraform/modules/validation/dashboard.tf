# Validation Module - CloudWatch Dashboard
#
# WHAT: CloudWatch dashboard for visualizing validation test results.
#
# WHY: Provides at-a-glance view of test health, trends, and failures.

resource "aws_cloudwatch_dashboard" "validation" {
  dashboard_name = "${var.name_prefix}-validation"
  
  dashboard_body = jsonencode({
    widgets = [
      # Header - Overall Status
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# 🧪 Government CCaaS Validation Dashboard\n**Environment:** ${var.environment} | **Last Updated:** See metrics below"
        }
      },
      
      # Step Functions Execution Summary
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Validation Workflow Executions"
          region = local.region
          stat   = "Sum"
          period = 86400
          metrics = [
            ["AWS/States", "ExecutionsStarted", "StateMachineArn", aws_sfn_state_machine.validation_workflow.arn, { color = "#2ca02c" }],
            [".", "ExecutionsSucceeded", ".", ".", { color = "#1f77b4" }],
            [".", "ExecutionsFailed", ".", ".", { color = "#d62728" }]
          ]
          view = "timeSeries"
        }
      },
      
      # Step Functions Success Rate
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Validation Success Rate"
          region = local.region
          metrics = [
            [{
              expression = "(m1/m2)*100"
              label      = "Success Rate %"
              id         = "e1"
            }],
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.validation_workflow.arn, { id = "m1", visible = false }],
            [".", "ExecutionsStarted", ".", ".", { id = "m2", visible = false }]
          ]
          view   = "gauge"
          yAxis  = { left = { min = 0, max = 100 } }
          period = 604800
          stat   = "Sum"
        }
      },
      
      # Execution Duration
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Validation Duration (seconds)"
          region = local.region
          metrics = [
            ["AWS/States", "ExecutionTime", "StateMachineArn", aws_sfn_state_machine.validation_workflow.arn]
          ]
          stat   = "Average"
          period = 3600
          view   = "timeSeries"
        }
      },
      
      # Lambda Function Metrics - Invocations
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Validation Lambda Invocations"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.orchestrator.function_name, { label = "Orchestrator" }],
            [".", ".", ".", aws_lambda_function.ai_validator.function_name, { label = "AI Validator" }],
            [".", ".", ".", aws_lambda_function.report_generator.function_name, { label = "Report Generator" }]
          ]
          stat   = "Sum"
          period = 3600
          view   = "timeSeries"
        }
      },
      
      # Lambda Function Metrics - Errors
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Validation Lambda Errors"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.orchestrator.function_name, { label = "Orchestrator", color = "#d62728" }],
            [".", ".", ".", aws_lambda_function.ai_validator.function_name, { label = "AI Validator", color = "#ff7f0e" }],
            [".", ".", ".", aws_lambda_function.report_generator.function_name, { label = "Report Generator", color = "#9467bd" }]
          ]
          stat   = "Sum"
          period = 3600
          view   = "timeSeries"
        }
      },
      
      # Lambda Duration
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration (ms)"
          region = local.region
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.orchestrator.function_name, { label = "Orchestrator" }],
            [".", ".", ".", aws_lambda_function.ai_validator.function_name, { label = "AI Validator" }],
            [".", ".", ".", aws_lambda_function.report_generator.function_name, { label = "Report Generator" }]
          ]
          stat   = "Average"
          period = 300
          view   = "timeSeries"
        }
      },
      
      # AI Validation Custom Metrics
      {
        type   = "metric"
        x      = 12
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "AI Validation Metrics"
          region = local.region
          metrics = [
            ["CCaaS/Validation", "LexAccuracy", "Environment", var.environment, { label = "Lex Accuracy %" }],
            [".", "BedrockLatency", ".", ".", { label = "Bedrock Latency (ms)" }],
            [".", "GuardrailBlocks", ".", ".", { label = "Guardrail Blocks" }]
          ]
          stat   = "Average"
          period = 3600
          view   = "timeSeries"
        }
      },
      
      # Test Results Summary (Custom Metrics)
      {
        type   = "metric"
        x      = 0
        y      = 19
        width  = 8
        height = 6
        properties = {
          title  = "Functional Test Results"
          region = local.region
          metrics = [
            ["CCaaS/Validation", "FunctionalTestsPassed", "Environment", var.environment, { color = "#2ca02c" }],
            [".", "FunctionalTestsFailed", ".", ".", { color = "#d62728" }]
          ]
          stat   = "Sum"
          period = 86400
          view   = "bar"
        }
      },
      
      # Security Test Results
      {
        type   = "metric"
        x      = 8
        y      = 19
        width  = 8
        height = 6
        properties = {
          title  = "Security Compliance Status"
          region = local.region
          metrics = [
            ["CCaaS/Validation", "SecurityTestsPassed", "Environment", var.environment, { color = "#2ca02c" }],
            [".", "SecurityTestsFailed", ".", ".", { color = "#d62728" }],
            [".", "ConfigRulesCompliant", ".", ".", { color = "#1f77b4" }]
          ]
          stat   = "Sum"
          period = 86400
          view   = "bar"
        }
      },
      
      # Load Test Results
      {
        type   = "metric"
        x      = 16
        y      = 19
        width  = 8
        height = 6
        properties = {
          title  = "Load Test Metrics"
          region = local.region
          metrics = [
            ["CCaaS/Validation", "LoadTestRPS", "Environment", var.environment, { label = "Requests/sec" }],
            [".", "LoadTestP99Latency", ".", ".", { label = "P99 Latency (ms)" }],
            [".", "LoadTestErrorRate", ".", ".", { label = "Error Rate %" }]
          ]
          stat   = "Average"
          period = 3600
          view   = "singleValue"
        }
      },
      
      # Recent Logs
      {
        type   = "log"
        x      = 0
        y      = 25
        width  = 24
        height = 6
        properties = {
          title  = "Recent Validation Logs"
          region = local.region
          query  = <<-EOT
            SOURCE '/aws/lambda/${aws_lambda_function.orchestrator.function_name}'
            | SOURCE '/aws/lambda/${aws_lambda_function.ai_validator.function_name}'
            | SOURCE '/aws/lambda/${aws_lambda_function.report_generator.function_name}'
            | fields @timestamp, @message
            | filter @message like /ERROR|WARN|FAIL|PASSED/
            | sort @timestamp desc
            | limit 50
          EOT
          view   = "table"
        }
      }
    ]
  })
}

# ============================================================================
# CLOUDWATCH ALARMS
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "validation_failed" {
  alarm_name          = "${var.name_prefix}-validation-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Validation workflow execution failed"
  
  dimensions = {
    StateMachineArn = aws_sfn_state_machine.validation_workflow.arn
  }
  
  alarm_actions = local.alert_topic_arn != "" ? [local.alert_topic_arn] : []
  ok_actions    = local.alert_topic_arn != "" ? [local.alert_topic_arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ai_accuracy_low" {
  alarm_name          = "${var.name_prefix}-ai-accuracy-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "LexAccuracy"
  namespace           = "CCaaS/Validation"
  period              = 3600
  statistic           = "Average"
  threshold           = var.ai_accuracy_threshold * 100
  alarm_description   = "AI intent recognition accuracy below threshold"
  
  dimensions = {
    Environment = var.environment
  }
  
  alarm_actions = local.alert_topic_arn != "" ? [local.alert_topic_arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ai_latency_high" {
  alarm_name          = "${var.name_prefix}-ai-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "BedrockLatency"
  namespace           = "CCaaS/Validation"
  period              = 300
  statistic           = "Average"
  threshold           = var.ai_latency_threshold_ms
  alarm_description   = "AI response latency above threshold"
  
  dimensions = {
    Environment = var.environment
  }
  
  alarm_actions = local.alert_topic_arn != "" ? [local.alert_topic_arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "security_test_failed" {
  alarm_name          = "${var.name_prefix}-security-test-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityTestsFailed"
  namespace           = "CCaaS/Validation"
  period              = 86400
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Security validation tests failed"
  
  dimensions = {
    Environment = var.environment
  }
  
  alarm_actions = local.alert_topic_arn != "" ? [local.alert_topic_arn] : []
  
  tags = local.common_tags
}
