# -------------------------------------------------------
# CONTAINER INSIGHTS
# Enables cluster-wide observability for EKS —
# CPU, memory, network, and pod-level metrics.
# One resource, zero application code changes.
# Metrics appear in CloudWatch under /aws/containerinsights
# -------------------------------------------------------
resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = 14

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# APPLICATION LOG GROUPS
# One per service — pods ship stdout/stderr here.
# -------------------------------------------------------
resource "aws_cloudwatch_log_group" "listings_service" {
  name              = "/eks/${var.project}/listings-service"
  retention_in_days = 14

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_log_group" "users_service" {
  name              = "/eks/${var.project}/users-service"
  retention_in_days = 14

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_log_group" "negotiation_service" {
  name              = "/eks/${var.project}/negotiation-service"
  retention_in_days = 14

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# ALB ALARMS
# Only created after ALB exists (after Helm deploy).
# Same pattern as Route53 API record.
# -------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.project}-alb-5xx-errors"
  alarm_description   = "ALB returning too many 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [var.owner_alerts_arn]
  ok_actions    = [var.owner_alerts_arn]

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count = var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.project}-alb-unhealthy-targets"
  alarm_description   = "ALB has unhealthy targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [var.owner_alerts_arn]

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# RDS ALARMS
# -------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  alarm_actions = [var.owner_alerts_arn]

  tags = {
    Project = var.project
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.project}-rds-connections-high"
  alarm_description   = "RDS connection count is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  alarm_actions = [var.owner_alerts_arn]

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# NEGOTIATION SERVICE ALARM
# -------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "negotiation_errors" {
  count = var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${var.project}-negotiation-errors"
  alarm_description   = "Negotiation service error rate is high — check Bedrock calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [var.owner_alerts_arn]

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# CLOUDWATCH DASHBOARD
# ALB widgets only added after ALB exists.
# RDS and DynamoDB widgets always present.
# -------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-dashboard"

  dashboard_body = jsonencode({
    widgets = concat(
      # RDS CPU + Connections — always present
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            title  = "RDS — CPU / Connections"
            region = var.region
            view   = "timeSeries"
            metrics = [
              ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier],
              [".", "DatabaseConnections", ".", "."]
            ]
            period = 60
            stat   = "Average"
          }
        },
        # DynamoDB — always present
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            title  = "DynamoDB — Negotiation Sessions"
            region = var.region
            view   = "timeSeries"
            metrics = [
              ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", var.dynamodb_table_name, "Operation", "PutItem"],
              [".", ".", ".", ".", "Operation", "Query"]
            ]
            period = 60
            stat   = "Average"
          }
        }
      ],
      # ALB widgets — only added after ALB exists
      var.alb_arn_suffix != "" ? [
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "API Request Volume (ALB)"
            region = var.region
            view   = "timeSeries"
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
            ]
            period = 60
            stat   = "Sum"
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "API Errors (4xx / 5xx)"
            region = var.region
            view   = "timeSeries"
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix],
              [".", "HTTPCode_Target_5XX_Count", ".", "."]
            ]
            period = 60
            stat   = "Sum"
          }
        }
      ] : []
    )
  })
}
