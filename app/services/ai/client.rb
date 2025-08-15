require "json"
require "net/http"
require "uri"

module Ai
  class Client
    def initialize(provider: ENV["AI_PROVIDER"], api_key: ENV["AI_API_KEY"], model: ENV["AI_MODEL"])
      @provider = provider
      @api_key = api_key
      @model = model
    end

    def chat(prompt)
      raise "Missing AI_API_KEY" if @api_key.to_s.empty?

      case @provider
      when "openai"
        chat_openai(prompt)
      else
        raise "Unsupported provider: #{@provider}"
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

      request_body[:temperature] = ENV["AI_TEMPERATURE"].to_f if ENV["AI_TEMPERATURE"].present?

      req.body = request_body.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
      raise "AI HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      content = data.dig("choices", 0, "message", "content").to_s.strip
      content
    end
  end
end
