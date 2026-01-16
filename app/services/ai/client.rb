require "json"
require "net/http"
require "uri"

module Ai
  class Client
    include Ai::Concerns::GeminiHttpClient

    def initialize(provider: ENV["AI_PROVIDER"], api_key: ENV["AI_API_KEY"], model: ENV["AI_MODEL"])
      @provider = provider || "gemini"
      @api_key = api_key
      @model = model
    end

    def chat(prompt)
      raise "Missing AI_API_KEY" if @api_key.to_s.empty?

      case @provider.downcase
      when "openai"
        chat_openai(prompt)
      when "gemini"
        chat_gemini(prompt)
      else
        raise "Unsupported provider: #{@provider}. Supported: openai, gemini"
      end
    end

    private

    def chat_openai(prompt)
      uri = URI.parse("https://api.openai.com/v1/chat/completions")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"] = "application/json"
      request_body = {
        model: @model || "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a precise JSON API. Return ONLY strict JSON, no markdown, no prose." },
          { role: "user", content: prompt }
        ]
      }

      if ENV["AI_TEMPERATURE"].present? && ENV["AI_TEMPERATURE"].to_f > 0.0
        request_body[:temperature] = ENV["AI_TEMPERATURE"].to_f
      end

      req.body = request_body.to_json

      # Set reasonable timeouts for AI API calls
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.open_timeout = 45  # 45 seconds to establish connection
      http.read_timeout = 180 # 3 minutes to receive response (increased for larger payloads)

      res = http.request(req)
      raise "AI HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      content = data.dig("choices", 0, "message", "content").to_s.strip

      # Extract usage metadata for cost tracking
      usage_data = data.dig("usage")
      usage = if usage_data
        {
          prompt_token_count: usage_data["prompt_tokens"],
          candidates_token_count: usage_data["completion_tokens"],
          total_token_count: usage_data["total_tokens"]
        }
      else
        {}
      end

      # Return hash with text and usage (matching VisionClient pattern)
      { text: content, usage: usage }
    end

    def chat_gemini(prompt)
      model_name = @model || "gemini-3-flash-preview"
      url = gemini_api_url(model_name)
      uri = URI(url)

      # Prepare the request payload
      payload = { contents: [ { parts: [ { text: prompt } ] } ] }

      begin
        request = build_gemini_request(uri, api_key: @api_key, payload: payload)
        http = build_gemini_http_client(uri)
        response = http.request(request)

        unless response.code == "200"
          Rails.logger.error("Gemini REST API Error: #{response.code} - #{response.body}")
          raise "Gemini API error: #{response.code} - #{response.body}"
        end

        result = JSON.parse(response.body)
        text = result.dig("candidates", 0, "content", "parts", 0, "text")

        # Extract usage metadata for cost tracking
        usage_metadata = result.dig("usageMetadata")
        usage = if usage_metadata
          {
            prompt_token_count: usage_metadata["promptTokenCount"],
            candidates_token_count: usage_metadata["candidatesTokenCount"],
            total_token_count: usage_metadata["totalTokenCount"]
          }
        else
          {}
        end

        # Return hash with text and usage (matching VisionClient pattern)
        { text: text, usage: usage }
      rescue JSON::ParserError => e
        Rails.logger.error("Gemini JSON parse error: #{e.message}")
        raise "Invalid JSON response from Gemini: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error("Gemini timeout error: #{e.message}")
        raise "Gemini API timeout: #{e.message}"
      rescue StandardError => e
        Rails.logger.error("Gemini unexpected error: #{e.message}")
        raise e
      end
    end
  end
end
