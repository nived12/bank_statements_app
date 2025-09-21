# app/services/ai/page_processor.rb
require "json"

module Ai
  class PageProcessor < ApplicationService
    include Concerns::PromptBuilder
    include Concerns::ResponseParser
    include Concerns::TextAnalysis
    include Concerns::BankStatementPrompter

    attr_reader :statement_file, :bank_name, :account_type, :categories, :client

    def initialize(statement_file:, client: Ai::GeminiClient.new)
      super()
      @statement_file = statement_file
      @bank_name = statement_file.bank.name
      @account_type = statement_file.bank_account.account_type.to_s
      @categories = statement_file.user.categories
      @client = client
    end

    def call_with_text(text_data)
      begin
        # Process text data with AI (for PII-protected text)
        result_data = process_text_with_ai(text_data)

        if result_data.present?
          success(result_data)
        else
          errors.add(:base, "Failed to process text with AI")
          failure
        end

      rescue => e
        Rails.logger.error("Ai::PageProcessor text processing failed: #{e.message}")
        errors.add(:base, "Text processing failed: #{e.message}")
        failure
      end
    end

    private

    def process_text_with_ai(text_data)
      begin
        # Build prompt for text processing (without PDF URL)
        prompt = build_text_processing_prompt_direct(text_data)

        if prompt.is_a?(ApplicationService::Response)
          if prompt.success?
            prompt = prompt.payload
          else
            Rails.logger.error("Prompt building failed: #{prompt.errors.full_messages}")
            return nil
          end
        end

        # Send text content directly to Gemini
        response = client.chat(prompt)

        if response.present?
          # Clean the response to remove markdown formatting
          cleaned_response = clean_ai_response(response)

          # Parse the response using the concern
          parsed_result = parse_ai_response(cleaned_response, "ai_page_processor")

          if parsed_result.success?
            data = parsed_result.payload

            # Add financial summary data that the concern doesn't handle
            data["opening_balance"] = extract_opening_balance_from_response(cleaned_response)
            data["closing_balance"] = extract_closing_balance_from_response(cleaned_response)

            # Return the extracted data
            {
              "transactions" => data["transactions"] || [],
              "financial_summaries" => data["financial_summaries"] || [],
              "extraction_source" => "ai_page_processor_text",
              "opening_balance" => data["opening_balance"],
              "closing_balance" => data["closing_balance"]
            }
          else
            Rails.logger.error("Ai::PageProcessor failed to parse AI response: #{parsed_result.errors.full_messages.join(', ')}")
            nil
          end
        else
          Rails.logger.error("Ai::PageProcessor AI returned empty response")
          nil
        end

      rescue => e
        Rails.logger.error("Ai::PageProcessor failed to process text with AI: #{e.message}")
        nil
      end
    end


    def build_text_processing_prompt_direct(text_data)
      build_bank_specific_text_prompt_direct(text_data, bank_name, account_type)
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
  end
end
