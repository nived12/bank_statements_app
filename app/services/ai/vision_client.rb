# app/services/ai/vision_client.rb
require "base64"

module Ai
  class VisionClient
    include Ai::Concerns::GeminiHttpClient

    class ApiError < StandardError; end
    class ConfigurationError < StandardError; end

    def initialize(api_key: ENV["AI_API_KEY"], model: ENV["AI_MODEL"])
      @api_key = api_key
      @model = model || "gemini-3-flash-preview"
      validate_configuration!
    end

    def analyze_document(image_paths, prompt)
      raise ArgumentError, "Image paths cannot be empty" if image_paths.blank?
      raise ArgumentError, "Prompt cannot be empty" if prompt.blank?

      max_retries = (ENV["AI_MAX_RETRIES"] || 2).to_i
      retry_delay_base = (ENV["AI_RETRY_DELAY_BASE"] || 2).to_i
      retries = 0

      begin
        parts = build_request_parts(prompt, image_paths)
        response = send_request(parts)
        extract_text_from_response(response)
      rescue ArgumentError => e
        # Re-raise ArgumentError without wrapping or retrying
        raise e
      rescue Timeout::Error, HTTParty::Error, ApiError => e
        retries += 1

        if retries <= max_retries && retryable_error?(e)
          delay = retry_delay_base ** retries  # Exponential: 2s, 4s, 8s
          Rails.logger.warn(
            "Vision API error (attempt #{retries}/#{max_retries}): #{e.message}. Retrying in #{delay}s..."
          )
          sleep(delay)
          retry
        else
          # Out of retries or non-retryable error
          raise e.is_a?(ApiError) ? e : ApiError.new("Request timeout: #{e.message}")
        end
      rescue StandardError => e
        raise ApiError, "Vision API error: #{e.message}"
      end
    end

    private

    def validate_configuration!
      raise ConfigurationError, "AI_API_KEY environment variable is required" if @api_key.blank?
      raise ConfigurationError, "Model name cannot be empty" if @model.blank?
    end

    def build_request_parts(prompt, image_paths)
      parts = [{ text: prompt }]

      image_paths.each do |path|
        unless File.exist?(path)
          Rails.logger.warn("Image file not found: #{path}")
          next
        end

        image_data = Base64.strict_encode64(File.read(path))
        mime_type = detect_mime_type(path)

        parts << { inline_data: { mime_type: mime_type, data: image_data } }
      end

      parts
    end

    def detect_mime_type(path)
      extension = File.extname(path).downcase
      case extension
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".png"
        "image/png"
      when ".webp"
        "image/webp"
      else
        "image/jpeg" # default fallback
      end
    end

    def send_request(parts)
      url = gemini_api_url(@model)
      payload = { contents: [{ parts: parts }] }

      Rails.logger.info("Sending request to Gemini Vision API with #{parts.count - 1} images")
      response = gemini_post(url, api_key: @api_key, payload: payload)

      handle_response(response)
    end

    def handle_response(response)
      case response.code.to_i
      when 200
        response.parsed_response
      when 400
        error_detail = extract_error_message(response)
        raise ApiError, "Bad request: #{error_detail}"
      when 401
        raise ApiError, "Authentication failed. Check your AI_API_KEY."
      when 404
        error_detail = extract_error_message(response)
        Rails.logger.error("404 Error - Full response body: #{response.body}")
        raise ApiError, "Model not found (404): #{error_detail}. Check model name: #{@model}"
      when 429
        raise ApiError, "Rate limit exceeded. Please try again later."
      when 500..599
        raise ApiError, "Gemini API server error (#{response.code})"
      else
        error_detail = extract_error_message(response)
        Rails.logger.error("Unexpected response (#{response.code}) - Full body: #{response.body}")
        raise ApiError, "Unexpected response code: #{response.code} - #{error_detail}"
      end
    end

    def extract_error_message(response)
      # HTTParty auto-parses JSON responses
      if response.parsed_response.is_a?(Hash)
        response.parsed_response.dig("error", "message") || "Unknown error"
      else
        response.body
      end
    end

    def extract_text_from_response(response)
      text = response.dig("candidates", 0, "content", "parts", 0, "text")

      if text.blank?
        Rails.logger.error("No text found in Vision API response: #{response.inspect}")
        raise ApiError, "No text content in response"
      end

      # Extract token usage metadata
      usage = extract_usage_metadata(response)

      # Return both text and metadata
      { text: text, usage: usage }
    end

    def extract_usage_metadata(response)
      metadata = response.dig("usageMetadata")
      return {} unless metadata

      {
        prompt_token_count: metadata["promptTokenCount"],
        candidates_token_count: metadata["candidatesTokenCount"],
        total_token_count: metadata["totalTokenCount"]
      }
    end

    # Determine if error is retryable
    def retryable_error?(error)
      # Retry on timeouts and rate limits, not on auth/validation errors
      return true if error.is_a?(Net::OpenTimeout) || error.is_a?(Net::ReadTimeout)

      if error.is_a?(ApiError)
        # Retry on rate limits (429) and server errors (5xx)
        return true if error.message.include?("Rate limit")
        return true if error.message.match?(/server error.*5\d\d/i)
      end

      false
    end
  end
end
