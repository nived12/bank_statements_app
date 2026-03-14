# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor < ApplicationService
    include Concerns::PromptBuilder
    include Concerns::ResponseParser
    include Concerns::BankStatementPrompter

    attr_reader :statement_file, :raw_text, :transactions, :client, :bank_name, :account_type, :categories

    def initialize(statement_file:, raw_text: nil, transactions: nil, client: Ai::Client.new)
      super()
      @statement_file = statement_file
      @raw_text = raw_text
      @transactions = transactions
      @client = client
      @bank_name = statement_file&.bank&.name
      @account_type = statement_file&.bank_account&.account_type.to_s
      @categories = statement_file&.user&.categories || []
    end

    def call
      if transactions.present?
        enhance_transactions
      elsif raw_text.present?
        process_text
      else
        errors.add(:base, "Either raw_text or transactions must be provided")
        failure
      end
    end

    private

    def enhance_transactions
      prompt_result = build_transaction_enhancement_prompt(transactions, bank_name, account_type)
      return failure_from(prompt_result) unless prompt_result.success?

      result = call_ai_and_parse(prompt_result.payload, "ai_transaction_enhancement")
      return result unless result.success?

      success(
        "transactions" => result.payload["transactions"] || [],
        "extraction_source" => "ai_transaction_enhancement"
      )
    end

    def process_text
      # 1. Call the new Python Brain instead of building local prompts
      result = Ai::BrainClient.call(raw_text: raw_text)

      return failure_from(result) unless result.success?

      data = result.payload

      # 2. Extract and format the data
      # The Python Brain returns the exact keys defined in your Pydantic model
      success(
        "transactions" => data["transactions"] || [],
        "financial_summaries" => data["financial_summaries"] || [],
        "extraction_source" => "vittio_brain_agent",
        "opening_balance" => data["opening_balance"],
        "closing_balance" => data["closing_balance"]
      )
    end

    def call_ai_and_parse(prompt, extraction_source)
      response = client.chat(prompt)
      response_text = response.is_a?(Hash) ? response[:text] : response

      if response_text.blank?
        errors.add(:base, "AI returned empty response")
        return failure
      end

      cleaned = clean_ai_response(response_text)
      parse_ai_response(cleaned, extraction_source)
    rescue => e
      errors.add(:base, "AI processing failed: #{e.message}")
      failure
    end

    def failure_from(result)
      result.errors.full_messages.each { |msg| errors.add(:base, msg) }
      failure
    end

    def clean_ai_response(response)
      response.strip.gsub(/^```json\s*/m, "").gsub(/^```\w*\s*/m, "").gsub(/\s*```$/m, "").strip
    end
  end
end
