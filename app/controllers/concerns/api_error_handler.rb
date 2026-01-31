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

    render_error(
      "NOT_FOUND",
      message: "Resource not found",
      status: :not_found
    )
  end

  ##
  # Handle 422 Validation errors
  #
  def handle_record_invalid(exception)
    Rails.logger.warn "API Validation error: #{exception.message}"

    render_error(
      "VALIDATION_ERROR",
      message: "Validation failed",
      details: format_validation_errors(exception.record.errors)
    )
  end

  ##
  # Handle 400 Parameter missing errors
  #
  def handle_parameter_missing(exception)
    Rails.logger.warn "API Parameter missing: #{exception.message}"

    render_error(
      "PARAMETER_MISSING",
      message: exception.message,
      status: :bad_request
    )
  end

  ##
  # Handle 500 Internal server errors
  # Only used in production (development should show full error)
  #
  def handle_internal_error(exception)
    Rails.logger.error "API Internal error: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace

    # Don't expose internal error details in production
    render_error(
      "INTERNAL_ERROR",
      message: "An internal error occurred. Please try again later.",
      status: :internal_server_error
    )
  end

  ##
  # Render error response with consistent format
  #
  # @param code [String] Machine-readable error code (SCREAMING_SNAKE_CASE)
  # @param message [String, nil] Optional human-readable error message (auto-generated from code if not provided)
  # @param status [Symbol] HTTP status code (default: :unprocessable_content)
  # @param details [Array, nil] Optional error details (e.g., validation errors)
  #
  # @example Basic usage (message auto-generated from code)
  #   render_error("INVALID_CREDENTIALS", status: :unauthorized)
  #   # => { error: { message: "Invalid credentials", code: "INVALID_CREDENTIALS" } }
  #
  # @example With custom message
  #   render_error("INVALID_CREDENTIALS", message: "Wrong email or password", status: :unauthorized)
  #
  # @example With details
  #   render_error("VALIDATION_ERROR", details: format_validation_errors(user.errors))
  #
  def render_error(code, message: nil, status: :unprocessable_content, details: nil)
    @error_code = code
    @error_message = message || humanize_error_code(code)
    @error_details = details if details.present?
    render "api/v1/shared/error", status: status
  end

  ##
  # Convert error code to human-readable message
  #
  # @param code [String] Error code in SCREAMING_SNAKE_CASE
  # @return [String] Human-readable error message
  #
  # @example
  #   humanize_error_code("INVALID_CREDENTIALS") # => "Invalid credentials"
  #   humanize_error_code("EMAIL_NOT_CONFIRMED") # => "Email not confirmed"
  #
  def humanize_error_code(code)
    code.to_s.downcase.tr("_", " ").capitalize
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
