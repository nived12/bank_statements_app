# frozen_string_literal: true

module Assistant
  # Converts token counts to USD cost based on provider + model pricing tables.
  # Pricing as of 2026-05. Update tables as providers change rates.
  class CostCalculator
    # Cost per 1M tokens, in USD. [input, output]
    # Gemini rates verified from https://ai.google.dev/gemini-api/docs/pricing on 2026-05-21.
    # Update this table whenever a new model is added to AI_MODEL / PRO_AI_MODEL / VISION_AI_MODEL.
    PRICING = {
      "gemini" => {
        "gemini-3.1-flash-lite"  => [0.25, 1.50],
        "gemini-3-flash-preview" => [0.50, 3.00],
        "gemini-3.5-flash"       => [1.50, 9.00],
        "gemini-1.5-flash"       => [0.15, 0.60],
        "gemini-1.5-pro"         => [1.25, 5.00],
        :default                 => [0.25, 1.50]
      },
      "openai" => {
        "gpt-4o-mini" => [0.15, 0.60],
        "gpt-4o"      => [2.50, 10.00],
        :default      => [0.15, 0.60]
      },
      "internal" => {
        default: [0.0, 0.0]
      }
    }.freeze

    def self.call(provider:, model:, prompt_tokens:, completion_tokens:)
      provider_table = PRICING[provider.to_s] || PRICING["gemini"]
      rates = provider_table[model.to_s] || provider_table[:default]
      input_rate, output_rate = rates

      cost = ((prompt_tokens.to_i * input_rate) + (completion_tokens.to_i * output_rate)) / 1_000_000.0
      cost.round(6)
    end
  end
end
