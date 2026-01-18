# frozen_string_literal: true

# AI API Pricing Configuration
module Ai
  module Concerns
    module Pricing
      # Exchange rate for USD to MXN conversion
      # Update this periodically to reflect current exchange rates
      USD_TO_MXN_RATE = ENV.fetch("USD_TO_MXN_RATE", "18.5").to_f

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
