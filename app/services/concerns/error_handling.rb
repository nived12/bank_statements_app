# frozen_string_literal: true

##
# ErrorHandling
# Generic concern module for error handling that can be included in any service
#
# Usage:
# include ErrorHandling in your service class and you can use:
#   log_error(error, context: "operation description", data: { key: value })
#
module ErrorHandling
  private

  # Generic error logging method
  def log_error(error, context: nil, data: nil, level: :error)
    message_parts = []
    message_parts << "[#{context}]" if context
    message_parts << error.message
    message = message_parts.join(" ")

    case level
    when :error
      Rails.logger.error(message)
      Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
    when :warn
      Rails.logger.warn(message)
    when :info
      Rails.logger.info(message)
    end

    Rails.logger.error("Context data: #{data.inspect}") if data && level == :error
  end
end
