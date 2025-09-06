# frozen_string_literal: true

##
# ApplicationService
# Base class for all service objects in the application
#
# Provides standardized success/failure response handling and automatic error logging
#
class ApplicationService
  include Errorable

  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs, &block).call
  end

  # Make errors accessible for testing and error handling
  attr_accessor :errors

  def initialize
    @errors = ActiveModel::Errors.new(self)
  end

  ##
  # Return a success response with optional payload
  #
  # @param payload [Object] the data to return with the success response
  # @return [Response] a success response object
  #
  def success(payload = nil)
    Response.new(success: true, payload: payload, errors: nil)
  end

  ##
  # Return a failure response with errors
  # Automatically logs any errors that were collected during processing
  #
  # @return [Response] a failure response object
  #
  def failure
    # Automatically log errors if any exist
    if errors&.any?
      service_name = self.class.name
      Rails.logger.error("#{service_name} failed with #{errors.count} error(s):")

      errors.each do |error|
        field = error.attribute == :base ? "base" : error.attribute
        Rails.logger.error("#{field}: #{error.message}")
      end

      # Log additional context if available
      if respond_to?(:context_for_logging) && context_for_logging.any?
        Rails.logger.error("#{service_name} context:")
        context_for_logging.each do |key, value|
          Rails.logger.error("#{key}: #{value}")
        end
      end
    end

    Response.new(success: false, payload: nil, errors: errors)
  end

  ##
  # Check if the service has any errors
  #
  # @return [Boolean] true if there are errors, false otherwise
  #
  def has_errors?
    errors&.any? || false
  end

  ##
  # Clear all errors
  #
  def clear_errors
    errors&.clear
  end



  ##
  # Add multiple errors from a Response object
  #
  # @param response [Response] the response object with errors to copy
  #
  def add_errors_from(response)
    return unless response.respond_to?(:errors) && response.errors&.any?

    response.errors.each do |error|
      errors.add(error.attribute, error.type, message: error.message)
    end
  end

  ##
  # Optional method for services to override to provide additional context for logging
  # This allows services to provide extra information when logging failures
  #
  # @return [Hash] additional context information for logging
  #
  def context_for_logging
    {}
  end

  ##
  # Response class for standardized service responses
  #
  class Response
    attr_reader :success, :payload, :errors

    def initialize(success:, payload:, errors:)
      @success = success
      @payload = payload
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
