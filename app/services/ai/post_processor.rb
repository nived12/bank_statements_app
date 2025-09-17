# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor < ApplicationService
    include Concerns::PromptBuilder
    include Concerns::ResponseParser
    include Concerns::TextAnalysis

    attr_reader :raw_text, :bank_name, :account_number, :categories, :client

    def initialize(raw_text:, bank_name: nil, account_number: nil, categories: nil, client: Ai::Client.new)
      super()
      @raw_text = raw_text
      @bank_name = bank_name
      @account_number = account_number
      @categories = categories
      @client = client
    end

    def call
      parsed_result = parsed_transactions?(raw_text)
      return failure unless parsed_result.success?

      # Always attempt AI processing - let AI decide what's a transaction
      # The parsed_transactions? check is just a hint, not a hard requirement
      result = if parsed_result.payload
        process_hybrid_enhancement(raw_text, categories)
      else
        # Even if it doesn't look like parsed transactions, try AI processing first
        # as it's better at understanding context than regex patterns
        process_fallback_parsing(raw_text, bank_name, account_number, categories)
      end

      return failure unless result.success?

      success(result.payload)
    rescue => e
      errors.add(:base, "AI processing failed: #{e.message}")
      failure
    end

    private

    def process_hybrid_enhancement(parsed_text, categories)
      essential_text_result = extract_keywords_inline(parsed_text)
      return failure unless essential_text_result.success?

      essential_text = essential_text_result.payload
      prompt_result = build_categorization_prompt(essential_text, categories)
      return failure unless prompt_result.success?

      prompt = prompt_result.payload
      content = client.chat(prompt)

      parse_ai_response(content, "ai_enhanced_parser")
    end

    def process_fallback_parsing(raw_text, bank_name, account_number, categories)
      prompt = build_full_parsing_prompt(raw_text, bank_name, account_number, categories)

      content = client.chat(prompt)

      parse_ai_response(content, "ai_parser_fallback")
    end

    # Override context_for_logging to provide additional context when logging failures
    def context_for_logging
      {
        "Raw text length" => raw_text&.length || "N/A",
        "Categories count" => categories&.count || "N/A"
      }
    end
  end
end
