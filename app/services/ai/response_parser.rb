# app/services/ai/response_parser.rb
require "json"

module Ai
  class ResponseParser < ApplicationService
    def initialize
      super()
    end

    def parse(content, extraction_source)
      unless content.is_a?(String) && extraction_source.is_a?(String)
        errors.add(:base, "content and extraction_source must be Strings")
        return failure
      end

      # Parse the AI response and return structured data
      begin
        json = JSON.parse(content)
        result = {
          "transactions" => json["transactions"] || [],
          "extraction_source" => extraction_source
        }
        success(result)
      rescue JSON::ParserError => e
        Rails.logger.warn("AI returned invalid JSON: #{e.message}")
        errors.add(:base, "AI returned invalid JSON: #{e.message}")
        failure
      rescue => e
        errors.add(:base, "Failed to parse AI response: #{e.message}")
        failure
      end
    end
  end
end
