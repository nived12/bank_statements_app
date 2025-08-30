# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor < ApplicationService
    def initialize(client: Ai::Client.new, **kwargs)
      super()
      @client = client
      @validator = TransactionValidator.new
      @text_processor = TextProcessor.new
      @prompt_builder = PromptBuilder.new
      @response_parser = ResponseParser.new

      # Store the kwargs for later use in the call method
      @call_kwargs = kwargs
    end

    def call(raw_text: nil, bank_name: nil, account_number: nil, categories: nil)
      # Use stored kwargs if no arguments provided (for backward compatibility)
      if raw_text.nil? && @call_kwargs.any?
        raw_text = @call_kwargs[:raw_text]
        bank_name = @call_kwargs[:bank_name]
        account_number = @call_kwargs[:account_number]
        categories = @call_kwargs[:categories]
      end

      @raw_text = raw_text
      @categories = categories

      parsed_result = @text_processor.parsed_transactions?(raw_text)
      return failure unless parsed_result.success?

      result = if parsed_result.payload
        process_hybrid_enhancement(raw_text, categories)
      else
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
      essential_text_result = @text_processor.extract_keywords_inline(parsed_text)
      return failure unless essential_text_result.success?

      essential_text = essential_text_result.payload
      prompt_result = @prompt_builder.build_categorization_prompt(essential_text, categories)
      return failure unless prompt_result.success?

      prompt = prompt_result.payload
      content = @client.chat(prompt)

      @response_parser.parse(content, "ai_enhanced_parser")
    end

    def process_fallback_parsing(raw_text, bank_name, account_number, categories)
      prompt = Ai::PromptBuilders::StatementToJson
        .new(bank_name: bank_name, account_number: account_number, categories: categories)
        .build(raw_text: raw_text)

      content = @client.chat(prompt)

      @response_parser.parse(content, "ai_parser_fallback")
    end

    # Override context_for_logging to provide additional context when logging failures
    def context_for_logging
      {
        "Raw text length" => @raw_text&.length || "N/A",
        "Categories count" => @categories&.count || "N/A"
      }
    end
  end
end
