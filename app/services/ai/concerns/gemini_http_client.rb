# app/services/ai/concerns/gemini_http_client.rb
module Ai
  module Concerns
    module GeminiHttpClient
      extend ActiveSupport::Concern

      DEFAULT_REQUEST_TIMEOUT = 180 # 3 minutes for API calls

      private

      def gemini_base_url
        ENV.fetch("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta")
      end

      def gemini_api_url(model_name, endpoint: "generateContent")
        "#{gemini_base_url}/models/#{model_name}:#{endpoint}"
      end

      # Make a POST request to Gemini API using HTTParty
      def gemini_post(url, api_key:, payload:, timeout: DEFAULT_REQUEST_TIMEOUT)
        HTTParty.post(
          url,
          headers: {
            "Content-Type" => "application/json",
            "X-Goog-Api-Key" => api_key
          },
          body: payload.to_json,
          timeout: timeout
        )
      end
    end
  end
end
