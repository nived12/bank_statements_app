# app/services/ai/concerns/gemini_http_client.rb
module Ai
  module Concerns
    module GeminiHttpClient
      extend ActiveSupport::Concern

      DEFAULT_REQUEST_TIMEOUT = 180 # 3 minutes for API calls
      DEFAULT_CONNECT_TIMEOUT = 45  # 45 seconds to establish connection

      private

      def gemini_base_url
        ENV.fetch("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta")
      end

      def build_gemini_http_client(uri, read_timeout: DEFAULT_REQUEST_TIMEOUT, connect_timeout: DEFAULT_CONNECT_TIMEOUT)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = read_timeout
        http.open_timeout = connect_timeout

        # In development, skip CRL (Certificate Revocation List) checks
        # which can fail on some macOS setups. This still validates the certificate chain.
        if Rails.env.development?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.cert_store = OpenSSL::X509::Store.new
          http.cert_store.set_default_paths
          # Disable CRL check flags (bitwise AND with 0 effectively disables it)
          http.cert_store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL & 0
        end

        http
      end

      def build_gemini_request(uri, api_key:, payload:)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["X-Goog-Api-Key"] = api_key
        request.body = payload.to_json
        request
      end

      def gemini_api_url(model_name, endpoint: "generateContent")
        "#{gemini_base_url}/models/#{model_name}:#{endpoint}"
      end
    end
  end
end
