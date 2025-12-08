# frozen_string_literal: true

##
# ApiErrorHandler
# Standardized error handling for API controllers
#
# Handles common errors and returns consistent JSON responses
#
module ApiErrorHandler
  extend ActiveSupport::Concern

  included do
    # Rescue from common exceptions
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from StandardError, with: :handle_internal_error if Rails.env.production?
  end

  private

  ##
  # Handle 404 Not Found errors
  #
  def handle_not_found(exception)
    Rails.logger.warn "API Record not found: #{exception.message}"

    @error_message = "Resource not found"
    @error_code = "NOT_FOUND"
    render "api/v1/shared/error", status: :not_found
  end

  ##
  # Handle 422 Validation errors
  #
  def handle_record_invalid(exception)
    Rails.logger.warn "API Validation error: #{exception.message}"

    @error_message = "Validation failed"
    @error_code = "VALIDATION_ERROR"
    @error_details = format_validation_errors(exception.record.errors)
    render "api/v1/shared/error", status: :unprocessable_entity
  end

  ##
  # Handle 400 Parameter missing errors
  #
  def handle_parameter_missing(exception)
    Rails.logger.warn "API Parameter missing: #{exception.message}"

    @error_message = exception.message
    @error_code = "PARAMETER_MISSING"
    render "api/v1/shared/error", status: :bad_request
  end

  ##
  # Handle 500 Internal server errors
  # Only used in production (development should show full error)
  #
  def handle_internal_error(exception)
    Rails.logger.error "API Internal error: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace

    # Don't expose internal error details in production
    @error_message = "An internal error occurred. Please try again later."
    @error_code = "INTERNAL_ERROR"
    render "api/v1/shared/error", status: :internal_server_error
  end

  ##
  # Format ActiveModel validation errors into a consistent structure
  #
  # @param errors [ActiveModel::Errors] The validation errors
  # @return [Array<Hash>] Formatted error details
  #
  def format_validation_errors(errors)
    errors.map do |error|
      {
        field: error.attribute,
        message: error.message,
        code: error.type
      }
    end
  end
end
