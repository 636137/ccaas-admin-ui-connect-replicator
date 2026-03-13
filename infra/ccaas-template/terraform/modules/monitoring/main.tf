# Monitoring Module - Main

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "census_agent" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Invocations"
          region = var.aws_region
          metrics = [
            for fn in var.lambda_function_names : [
              "AWS/Lambda", "Invocations",
              "FunctionName", fn,
              { stat = "Sum", period = 300 }
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          metrics = [
            for fn in var.lambda_function_names : [
              "AWS/Lambda", "Errors",
              "FunctionName", fn,
              { stat = "Sum", period = 300 }
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration"
          region = var.aws_region
          metrics = [
            for fn in var.lambda_function_names : [
              "AWS/Lambda", "Duration",
              "FunctionName", fn,
              { stat = "Average", period = 300 }
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB Read/Write Capacity"
          region = var.aws_region
          metrics = concat(
            [
              for table in var.dynamodb_table_names : [
                "AWS/DynamoDB", "ConsumedReadCapacityUnits",
                "TableName", table,
                { stat = "Sum", period = 300 }
              ]
            ],
            [
              for table in var.dynamodb_table_names : [
                "AWS/DynamoDB", "ConsumedWriteCapacityUnits",
                "TableName", table,
                { stat = "Sum", period = 300 }
              ]
            ]
          )
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Lex Bot Metrics"
          region = var.aws_region
          metrics = [
            ["AWS/Lex", "MissedUtteranceCount", "BotId", var.lex_bot_id, { stat = "Sum", period = 300 }],
            ["AWS/Lex", "RuntimeSuccessfulRequestCount", "BotId", var.lex_bot_id, { stat = "Sum", period = 300 }],
            ["AWS/Lex", "RuntimeRequestCount", "BotId", var.lex_bot_id, { stat = "Sum", period = 300 }]
          ]
        }
      }
    ]
  })
}

# Lambda Error Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.name_prefix}-${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function ${each.value} error count exceeded threshold"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.name_prefix}-${each.value}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 25000  # 25 seconds
  alarm_description   = "Lambda function ${each.value} duration exceeded threshold"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# DynamoDB Throttling Alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = toset(var.dynamodb_table_names)

  alarm_name          = "${var.name_prefix}-${each.value}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "DynamoDB table ${each.value} throttling detected"

  dimensions = {
    TableName = each.value
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# Lex Missed Utterance Alarm
resource "aws_cloudwatch_metric_alarm" "lex_missed_utterances" {
  alarm_name          = "${var.name_prefix}-lex-missed-utterances"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MissedUtteranceCount"
  namespace           = "AWS/Lex"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "High number of missed utterances in Lex bot"

  dimensions = {
    BotId = var.lex_bot_id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# Custom metric for survey completion rate
resource "aws_cloudwatch_log_metric_filter" "survey_completions" {
  name           = "${var.name_prefix}-survey-completions"
  pattern        = "{ $.status = \"COMPLETE\" }"
  log_group_name = "/aws/lambda/${var.lambda_function_names[0]}"

  metric_transformation {
    name      = "SurveyCompletions"
    namespace = "CensusEnumerator"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "survey_refusals" {
  name           = "${var.name_prefix}-survey-refusals"
  pattern        = "{ $.status = \"REFUSED\" }"
  log_group_name = "/aws/lambda/${var.lambda_function_names[0]}"

  metric_transformation {
    name      = "SurveyRefusals"
    namespace = "CensusEnumerator"
    value     = "1"
  }
}
