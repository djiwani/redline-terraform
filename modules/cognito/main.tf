# -------------------------------------------------------
# USER POOL
# Handles signup, login, email verification, and
# JWT token issuance for Redline users.
# Users must be signed in to start a negotiation.
# -------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-user-pool"

  # Users sign in with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Allow anyone to sign up — no admin approval needed
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # Email verification message
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Redline — Verify your email"
    email_message        = "Your Redline verification code is {####}"
  }

  # Store user's max budget preference as a custom attribute
  # Useful for pre-filling the negotiation form
  schema {
    name                = "max_budget"
    attribute_data_type = "Number"
    mutable             = true
    required            = false
    number_attribute_constraints {
      min_value = "0"
      max_value = "1000000"
    }
  }

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# USER POOL CLIENT
# What the frontend uses to authenticate users.
# No client secret — public client for a SPA.
# -------------------------------------------------------
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",        # Secure Remote Password — most secure flow
    "ALLOW_USER_PASSWORD_AUTH",   # Simple password auth — easier for dev/testing
    "ALLOW_REFRESH_TOKEN_AUTH"    # Allows token refresh without re-login
  ]

  prevent_user_existence_errors = "ENABLED"

  # Token lifetimes
  access_token_validity  = 1  # 1 hour
  id_token_validity      = 1  # 1 hour
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Allowed callback URLs for hosted UI
  # Update this when frontend CloudFront URL is known
  callback_urls = ["https://${var.subdomain}"]
  logout_urls   = ["https://${var.subdomain}"]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
}

# -------------------------------------------------------
# USER POOL DOMAIN
# Gives Cognito a hosted UI URL for login/signup.
# Users go here to authenticate before being redirected
# back to the Redline frontend with a JWT.
# URL: https://redline-auth.auth.us-east-1.amazoncognito.com
# -------------------------------------------------------
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}
