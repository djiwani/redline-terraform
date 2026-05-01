# -------------------------------------------------------
# SNS TOPICS
#
# Two separate topics — one for each negotiation outcome.
# Keeping them separate means you could subscribe different
# endpoints to each in the future (e.g. different Lambda
# handlers, different email templates etc.)
# -------------------------------------------------------

# Fired when buyer and seller bots reach an agreed price
resource "aws_sns_topic" "deal_reached" {
  name = "${var.project}-deal-reached"

  tags = {
    Project = var.project
  }
}

# Fired when negotiation hits 10 rounds with no deal,
# or when buyer budget is below seller floor price on round 1
resource "aws_sns_topic" "negotiation_failed" {
  name = "${var.project}-negotiation-failed"

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# EMAIL SUBSCRIPTIONS
# Notifies the user when their negotiation completes.
# In a real app you'd subscribe dynamically per user —
# for a portfolio project a single email is fine.
# -------------------------------------------------------
resource "aws_sns_topic_subscription" "deal_reached_email" {
  topic_arn = aws_sns_topic.deal_reached.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_subscription" "negotiation_failed_email" {
  topic_arn = aws_sns_topic.negotiation_failed.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# -------------------------------------------------------
# OWNER ALERTS TOPIC
# Operational alerts for you — CloudWatch alarms fire here.
# Same pattern as OpenCourt's owner_alerts topic.
# Separate from user notifications so the two never mix.
# -------------------------------------------------------
resource "aws_sns_topic" "owner_alerts" {
  name = "${var.project}-owner-alerts"

  tags = {
    Project = var.project
  }
}

resource "aws_sns_topic_subscription" "owner_alerts_email" {
  topic_arn = aws_sns_topic.owner_alerts.arn
  protocol  = "email"
  endpoint  = var.owner_email
}
