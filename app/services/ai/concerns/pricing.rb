# frozen_string_literal: true

# AI API Pricing Configuration
module Ai
  module Concerns
    module Pricing
      # Fetch current USD to MXN exchange rate from exchangerate-api.com
      # Falls back to ENV variable if fetch fails
      # Cached for 24 hours to minimize API calls
      def self.usd_to_mxn_rate
        Rails.cache.fetch("exchange_rate_usd_mxn", expires_in: 24.hours) do
          fetch_live_exchange_rate || fallback_exchange_rate
        end
      end

      # Fetch live exchange rate from exchangerate-api.com (free tier, no API key)
      def self.fetch_live_exchange_rate
        response = HTTParty.get("https://open.er-api.com/v6/latest/USD", timeout: 10)

        if response.success?
          rate = response.dig("rates", "MXN")

          return unless rate && rate > 0

          rate.to_f
        else
          Rails.logger.warn("HTTP error from exchangerate-api.com: #{response.code}")
          nil
        end
      rescue StandardError => e
        Rails.logger.warn("Failed to fetch live exchange rate: #{e.message}. Using fallback.")
        nil
      end

      # Fallback to ENV variable or hardcoded default
      def self.fallback_exchange_rate
        ENV.fetch("USD_TO_MXN_RATE", "18.5").to_f
      end

      # Main exchange rate constant - uses live rate or fallback
      USD_TO_MXN_RATE = usd_to_mxn_rate

      # Gemini Model Pricing (per 1M tokens)
      module Gemini
        # Gemini 3 Flash Preview (Vision)
        FLASH_PREVIEW_INPUT_COST = 0.15
        FLASH_PREVIEW_OUTPUT_COST = 0.60

        # Gemini 2.0 Flash Lite (Categorization)
        FLASH_LITE_INPUT_COST = 0.075
        FLASH_LITE_OUTPUT_COST = 0.30
      end
    end
  end
end
