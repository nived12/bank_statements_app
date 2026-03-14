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
  # Authenticate user via JWT token, or internal service bypass.
  # Internal service: if X-Internal-Service-Token matches BRAIN_API_KEY and X-User-Id
  # is present, sets @current_user to that user and skips JWT (service-to-service only).
  # Otherwise extracts token from Authorization header and validates JWT.
  #
  def authenticate_api_user!
    if internal_service_request?
      user = User.find_by(id: request.headers["X-User-Id"])
      if user.blank?
        return render_error(
          "UNAUTHORIZED",
          message: "User not found for internal service request",
          status: :unauthorized
        )
      end
      @current_user = user
      Current.user = user
      return
    end

    token = extract_token_from_header

    if token.blank?
      return render_error(
        "UNAUTHORIZED",
        message: "Missing authorization token",
        status: :unauthorized
      )
    end

    decoded_token = JsonWebToken.decode(token)

    if decoded_token.blank?
      return render_error(
        "UNAUTHORIZED",
        message: "Invalid or expired token",
        status: :unauthorized
      )
    end

    # Verify it's an access token
    unless decoded_token[:type] == "access"
      return render_error(
        "UNAUTHORIZED",
        message: "Invalid token type",
        status: :unauthorized
      )
    end

    # Find user
    user = User.find_by(id: decoded_token[:user_id])

    if user.blank?
      return render_error(
        "UNAUTHORIZED",
        message: "User not found",
        status: :unauthorized
      )
    end

    # Verify JTI matches (token hasn't been revoked)
    if user.jti != decoded_token[:jti]
      return render_error(
        "UNAUTHORIZED",
        message: "Token has been revoked",
        status: :unauthorized
      )
    end

    # Set current user
    @current_user = user
    Current.user = user
  end

  ##
  # True if request is from an internal service (Vittio Brain) with valid token and user id.
  # Only for service-to-service calls; BRAIN_API_KEY must be set and match X-Internal-Service-Token.
  #
  def internal_service_request?
    token = request.headers["X-Internal-Service-Token"]
    user_id = request.headers["X-User-Id"]
    expected = ENV["BRAIN_API_KEY"]
    return false if token.blank? || user_id.blank? || expected.blank?
    return false unless ActiveSupport::SecurityUtils.secure_compare(token, expected)

    true
  end

  ##
  # Extract JWT token from Authorization header
  # Expected format: "Authorization: Bearer <token>"
  #
  # @return [String, nil] The extracted token or nil
  #
  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return if auth_header.blank?

    # Extract token from "Bearer <token>" format
    # Must start with "Bearer " and have exactly 2 parts (scheme + token)
    parts = auth_header.split(" ")
    return unless parts.length == 2 && parts[0] == "Bearer"

    parts[1]
  end

  ##
  # Optional: Get current user (already set by authenticate_api_user!)
  # This allows controllers to use current_user helper method
  #
  def current_user
    @current_user
  end
end
