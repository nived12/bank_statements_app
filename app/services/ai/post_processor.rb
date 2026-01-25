# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor < ApplicationService
    include Concerns::PromptBuilder
    include Concerns::ResponseParser
    include Concerns::TextAnalysis
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
      # Determine processing path based on available data
      if transactions.present?
        # Transaction enhancement path
        result_data = process_transactions_with_ai(transactions)
        error_message = "Failed to enhance transactions with AI"
      elsif raw_text.present?
        # Full text processing path
        result_data = process_text_with_ai(raw_text)
        error_message = "Failed to process text with AI"
      else
        errors.add(:base, "Either raw_text or transactions must be provided")
        return failure
      end

      if result_data.present?
        success(result_data)
      else
        errors.add(:base, error_message)
        failure
      end
    rescue => e
      errors.add(:base, "AI processing failed: #{e.message}")
      failure
    end

    private

    def process_text_with_ai(text)
      begin
        # Build prompt for text processing
        prompt_result = build_bank_statement_prompt(text, bank_name, account_type)

        if prompt_result.success?
          prompt = prompt_result.payload
        else
          Rails.logger.error("Prompt building failed: #{prompt_result.errors.full_messages}")
          return
        end

        # Send text content directly to AI
        response = client.chat(prompt)

        # Extract text from response hash (client returns { text:, usage: })
        response_text = response.is_a?(Hash) ? response[:text] : response

        if response_text.present?
          # Clean the response to remove markdown formatting
          cleaned_response = clean_ai_response(response_text)

          # Parse the response using the concern
          parsed_result = parse_ai_response(cleaned_response, "ai_post_processor")

          if parsed_result.success?
            data = parsed_result.payload

            # Add financial summary data that the concern doesn't handle
            data["opening_balance"] = extract_opening_balance_from_response(cleaned_response)
            data["closing_balance"] = extract_closing_balance_from_response(cleaned_response)

            # Return the extracted data
            {
              "transactions" => data["transactions"] || [],
              "financial_summaries" => data["financial_summaries"] || [],
              "extraction_source" => "ai_post_processor_text",
              "opening_balance" => data["opening_balance"],
              "closing_balance" => data["closing_balance"]
            }
          else
            Rails.logger.error(
              "Ai::PostProcessor failed to parse AI response: #{parsed_result.errors.full_messages.join(", ")}"
            )
            nil
          end
        else
          Rails.logger.error("Ai::PostProcessor AI returned empty response")
          nil
        end

      rescue => e
        Rails.logger.error("Ai::PostProcessor failed to process text with AI: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
        nil
      end
    end

    def process_transactions_with_ai(transactions)
      begin
        # Build prompt for transaction enhancement
        prompt_result = build_transaction_enhancement_prompt(transactions, bank_name, account_type)

        if prompt_result.success?
          prompt = prompt_result.payload
        else
          Rails.logger.error("Transaction enhancement prompt building failed: #{prompt_result.errors.full_messages}")
          return
        end

        # Call AI API
        response = client.chat(prompt)

        # Extract text from response hash (client returns { text:, usage: })
        response_text = response.is_a?(Hash) ? response[:text] : response

        if response_text.blank?
          Rails.logger.error("AI PostProcessor: Empty response from Gemini API")
          return
        end

        # Clean the response to remove markdown formatting
        cleaned_response = clean_ai_response(response_text)

        # Check if response looks truncated (doesn't end with proper JSON closing)
        if cleaned_response.strip.end_with?('"') && !cleaned_response.strip.end_with?('"}')
          Rails.logger.error("AI PostProcessor: Response appears truncated - ends with: #{cleaned_response[-50..-1]}")
          return
        end

        # Additional check: try to parse JSON to detect truncation
        begin
          JSON.parse(cleaned_response)
        rescue JSON::ParserError => e
          Rails.logger.error("AI PostProcessor: JSON parsing failed, likely truncated: #{e.message}")
          Rails.logger.error("AI PostProcessor: Response ends with: #{cleaned_response[-100..-1]}")
          return
        end

        # Parse the response using the concern
        parsed_result = parse_ai_response(cleaned_response, "ai_transaction_enhancement")

        if parsed_result.success?
          data = parsed_result.payload

          # Return only the enhanced transactions
          {
            "transactions" => data["transactions"] || [],
            "extraction_source" => "ai_transaction_enhancement"
          }
        else
          Rails.logger.error(
            "Ai::PostProcessor failed to parse transaction enhancement response: #{parsed_result.errors.full_messages.join(", ")}"
          )
          nil
        end

      rescue => e
        Rails.logger.error("Ai::PostProcessor failed to enhance transactions with AI: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
        nil
      end
    end

    def extract_opening_balance_from_response(response)
      # Extract opening balance from AI response
      begin
        json = JSON.parse(response)
        json["opening_balance"]
      rescue
        nil
      end
    end

    def extract_closing_balance_from_response(response)
      # Extract closing balance from AI response
      begin
        json = JSON.parse(response)
        json["closing_balance"]
      rescue
        nil
      end
    end

    def clean_ai_response(response)
      # Remove markdown formatting from AI response
      cleaned = response.strip

      # Remove ```json and ``` wrappers (more aggressive)
      cleaned = cleaned.gsub(/^```json\s*/m, "")
      cleaned = cleaned.gsub(/\s*```$/m, "")

      # Remove any other markdown code blocks
      cleaned = cleaned.gsub(/^```\w*\s*/m, "")
      cleaned = cleaned.gsub(/\s*```$/m, "")

      # Remove any leading/trailing whitespace and newlines
      cleaned.strip
    end

    # Override context_for_logging to provide additional context when logging failures
    def context_for_logging
      {
        "Statement file ID" => statement_file&.id || "N/A",
        "Bank name" => statement_file&.bank&.name || "N/A",
        "Account type" => statement_file&.bank_account&.account_type || "N/A",
        "Categories count" => statement_file&.user&.categories&.count || "N/A"
      }
    end
  end
end
