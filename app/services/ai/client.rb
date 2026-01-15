require "json"
require "net/http"
require "uri"

module Ai
  class Client
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
      model_name = @model || "gemini-2.0-flash-lite"
      url = "https://generativelanguage.googleapis.com/v1beta/models/#{model_name}:generateContent?key=#{@api_key}"

      # Prepare the request payload
      payload = { contents: [ { parts: [ { text: prompt } ] } ] }


      begin
        require "net/http"
        require "uri"
        require "json"

        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        # In development, skip CRL (Certificate Revocation List) checks
        # which can fail on some macOS setups. This still validates the certificate chain.
        if Rails.env.development?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          # Disable CRL check flags
          http.cert_store = OpenSSL::X509::Store.new
          http.cert_store.set_default_paths
          http.cert_store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL & 0
        end

        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)

        if response.code == "200"
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
        else
          Rails.logger.error("Gemini REST API Error: #{response.code} - #{response.body}")
          raise "Gemini API error: #{response.code} - #{response.body}"
        end
      rescue => e
        Rails.logger.error("Gemini REST API Error: #{e.message}")
        raise e
      end
    end
  end
end
