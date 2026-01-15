# app/services/ai/vision_client.rb
require "net/http"
require "json"
require "base64"

module Ai
  class VisionClient
    class ApiError < StandardError; end
    class ConfigurationError < StandardError; end

    GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    DEFAULT_MODEL = ENV["AI_MODEL"] || "gemini-3-flash-preview"
    REQUEST_TIMEOUT = 180 # 3 minutes for vision API (can be slower)
    CONNECT_TIMEOUT = 45

    # Disable CRL (Certificate Revocation List) checks in development
    # This prevents SSL errors on some macOS setups while still validating certificate chain
    DISABLE_CRL_CHECKS = 0 # Bitwise AND with V_FLAG_CRL_CHECK_ALL effectively disables it

    def initialize(api_key: ENV["AI_API_KEY"], model: DEFAULT_MODEL)
      @api_key = api_key
      @model = model
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
      rescue Net::OpenTimeout, Net::ReadTimeout, ApiError => e
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
      rescue JSON::ParserError => e
        raise ApiError, "Invalid JSON response: #{e.message}"
      rescue StandardError => e
        raise ApiError, "Vision API error: #{e.message}"
      end
    end

    private

    def validate_configuration!
      if @api_key.blank?
        raise ConfigurationError, "AI_API_KEY environment variable is required"
      end

      if @model.blank?
        raise ConfigurationError, "Model name cannot be empty"
      end
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

        parts << {
          inline_data: {
            mime_type: mime_type,
            data: image_data
          }
        }
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
      uri = build_uri
      request = build_http_request(uri, parts)
      http = build_http_client(uri)

      Rails.logger.info("Sending request to Gemini Vision API with #{parts.count - 1} images")
      response = http.request(request)

      handle_response(response)
    end

    def build_uri
      # Remove API key from URL (security: prevent logging API key)
      URI("#{GEMINI_BASE_URL}/models/#{@model}:generateContent")
    end

    def build_http_request(uri, parts)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Goog-Api-Key"] = @api_key  # Use header instead of URL parameter
      request.body = {
        contents: [{ parts: parts }]
      }.to_json
      request
    end

    def build_http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = REQUEST_TIMEOUT
      http.open_timeout = CONNECT_TIMEOUT

      # In development, skip CRL (Certificate Revocation List) checks
      # which can fail on some macOS setups. This still validates the certificate chain.
      if Rails.env.development?
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        # Disable CRL check flags
        http.cert_store = OpenSSL::X509::Store.new
        http.cert_store.set_default_paths
        http.cert_store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL & 0
      end

      http
    end

    def handle_response(response)
      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 400
        error_detail = extract_error_message(response.body)
        raise ApiError, "Bad request: #{error_detail}"
      when 401
        raise ApiError, "Authentication failed. Check your AI_API_KEY."
      when 404
        error_detail = extract_error_message(response.body)
        Rails.logger.error("404 Error - Full response body: #{response.body}")
        raise ApiError, "Model not found (404): #{error_detail}. Check model name: #{@model}"
      when 429
        raise ApiError, "Rate limit exceeded. Please try again later."
      when 500..599
        raise ApiError, "Gemini API server error (#{response.code})"
      else
        error_detail = extract_error_message(response.body)
        Rails.logger.error("Unexpected response (#{response.code}) - Full body: #{response.body}")
        raise ApiError, "Unexpected response code: #{response.code} - #{error_detail}"
      end
    end

    def extract_error_message(response_body)
      parsed = JSON.parse(response_body)
      parsed.dig("error", "message") || "Unknown error"
    rescue JSON::ParserError
      response_body
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
