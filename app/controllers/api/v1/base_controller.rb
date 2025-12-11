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

      protected

      ##
      # Format ActiveModel validation errors for API response
      # Converts errors hash into array of field-level error objects
      #
      # @param errors [ActiveModel::Errors] The validation errors object
      # @return [Array<Hash>] Array of formatted error objects
      #
      # @example
      #   format_validation_errors(user.errors)
      #   # => [
      #   #   { field: "email", message: "Email can't be blank", code: "BLANK" },
      #   #   { field: "password", message: "Password is too short", code: "TOO_SHORT" }
      #   # ]
      #
      def format_validation_errors(errors)
        errors.details.flat_map do |field, details_array|
          details_array.map.with_index do |detail, index|
            {
              field: field.to_s,
              message: errors.full_messages_for(field)[index] || errors.full_messages_for(field).first,
              code: detail[:error].to_s.upcase
            }
          end
        end
      end
    end
  end
end
