# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::BaseController
    # Base controller for all API v1 endpoints
    #
    # Key features:
    # - JSON-only responses
    # - JWT authentication
    # - CSRF protection disabled (using JWT instead)
    # - Custom error handling
    # - Rate limiting headers
    #
    class BaseController < ActionController::API
      include ApiAuthenticatable
      include ApiErrorHandler

      # Override current_user to use JWT authentication
      # (ApiAuthenticatable sets this via before_action)
      attr_reader :current_user
    end
  end
end
