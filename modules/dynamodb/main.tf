# -------------------------------------------------------
# DYNAMODB — NEGOTIATION SESSIONS TABLE
#
# Stores the full conversation history for each
# negotiation session. One item per message per round.
#
# Schema:
#   PK: session_id (UUID)       — identifies the negotiation
#   SK: round_number (Number)   — which round of negotiation
#
# GSI: user_id-index
#   PK: user_id                 — query all sessions for a user
#   SK: timestamp               — sorted by time
#
# Max 10 rounds × 2 messages (buyer + seller) = 20 items per session
# TTL auto-deletes old sessions after 7 days
# -------------------------------------------------------
resource "aws_dynamodb_table" "negotiation_sessions" {
  name         = "${var.project}-negotiation-sessions"
  billing_mode = "PAY_PER_REQUEST" # On-demand — no capacity planning needed
  hash_key     = "session_id"
  range_key    = "round_number"

  attribute {
    name = "session_id"
    type = "S" # String
  }

  attribute {
    name = "round_number"
    type = "N" # Number
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # TTL — automatically deletes items after 7 days
  # Keeps the table clean without any cleanup code
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # GSI — lets negotiation-service query "all sessions for user X"
  # Used to show a user their negotiation history
  global_secondary_index {
    name            = "user_id-index"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL" # Include all attributes in GSI results
  }

  tags = {
    Project = var.project
  }
}
