# frozen_string_literal: true

##
# ApiAuthenticatable
# Concern for API authentication using JWT tokens
#
# This concern provides JWT-based authentication for API controllers.
# It extracts and validates JWT tokens from the Authorization header.
#
# Usage:
#   class Api::V1::BaseController < ActionController::API
#     include ApiAuthenticatable
#   end
#
module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user

    # Override authenticate! to use JWT instead of session
    before_action :authenticate_api_user!
  end

  private

  ##
  # Authenticate user via JWT token
  # Extracts token from Authorization header and validates it
  #
  def authenticate_api_user!
    token = extract_token_from_header

    if token.blank?
      render_unauthorized("Missing authorization token")
      return
    end

    decoded_token = JsonWebToken.decode(token)

    if decoded_token.blank?
      render_unauthorized("Invalid or expired token")
      return
    end

    # Verify it's an access token
    unless decoded_token[:type] == "access"
      render_unauthorized("Invalid token type")
      return
    end

    # Find user
    user = User.find_by(id: decoded_token[:user_id])

    if user.blank?
      render_unauthorized("User not found")
      return
    end

    # Verify JTI matches (token hasn't been revoked)
    if user.jti != decoded_token[:jti]
      render_unauthorized("Token has been revoked")
      return
    end

    # Set current user
    @current_user = user
    Current.user = user
  end

  ##
  # Extract JWT token from Authorization header
  # Expected format: "Authorization: Bearer <token>"
  #
  # @return [String, nil] The extracted token or nil
  #
  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil if auth_header.blank?

    # Extract token from "Bearer <token>" format
    # Must start with "Bearer " and have exactly 2 parts (scheme + token)
    parts = auth_header.split(" ")
    return nil unless parts.length == 2 && parts[0] == "Bearer"

    parts[1]
  end

  ##
  # Render unauthorized response
  #
  # @param message [String] Error message to return
  #
  def render_unauthorized(message = "Unauthorized")
    render json: {
      error: {
        message: message,
        code: "UNAUTHORIZED"
      }
    }, status: :unauthorized
  end

  ##
  # Optional: Get current user (already set by authenticate_api_user!)
  # This allows controllers to use current_user helper method
  #
  def current_user
    @current_user
  end
end
