# app/services/statements/handlers/text_with_ai_handler.rb
#
# Text + AI Handler: Parser-first approach with AI fallback
#
# Strategy:
# 1. Try deterministic parser first (no AI, fast, deterministic)
# 2. If parser succeeds → use AI for categorization only
# 3. If parser fails/no transactions → use AI for extraction + categorization
#
module Statements
  module Handlers
    class TextWithAiHandler < ApplicationService
      include ErrorHandling
      include Concerns::ImportFinalizer

      def initialize(statement_file, raw_text)
        super()
        @statement_file = statement_file
        @raw_text = raw_text
      end

      def call
        Rails.logger.info("Using text + AI path (parser-first with AI fallback)")

        # Step 1: Try deterministic parser first
        parser_result = try_deterministic_parser
        if parser_result && has_transactions?(parser_result)
          Rails.logger.info("Deterministic parser succeeded, using AI for categorization only")
          return process_with_parser_result(parser_result)
        end

        # Step 2: Parser failed or no transactions - use full AI extraction
        Rails.logger.info("Parser yielded no transactions, falling back to AI extraction")
        process_with_ai_extraction
      end

      private

      # Try the deterministic parser (no AI)
      def try_deterministic_parser
        parser_class = @statement_file.bank_account.parser_class

        # If parser_class is Ai::PostProcessor, there's no deterministic parser
        if parser_class == Ai::PostProcessor
          Rails.logger.info("No deterministic parser available for this bank")
          return
        end

        Rails.logger.info("Trying deterministic parser: #{parser_class.name}")
        parser_result = parser_class.call(@raw_text)

        if parser_result.success?
          data = parser_result.payload
          data["extraction_source"] = "deterministic_parser"
          data
        else
          Rails.logger.warn("Parser failed: #{parser_result.errors.full_messages.join(", ")}")
          nil
        end
      rescue => e
        Rails.logger.error("Parser error: #{e.message}")
        nil
      end

      # Process using parser result + rule-based + AI categorization
      def process_with_parser_result(parsed_data)
        transactions = parsed_data["transactions"] || []

        if transactions.empty?
          Rails.logger.info("No transactions to categorize, importing directly")
          return import_and_finalize(parsed_data)
        end

        # Rows a rule already categorizes do not need to be paid for at Gemini. This pass
        # only decides what to send; import_and_finalize applies the rules for real, on
        # every strategy, which is why hits are not counted here.
        matched, unmatched = partition_by_category_rules(transactions)

        if unmatched.empty?
          Rails.logger.info("Category rules cover all #{matched.length} transactions, skipping AI")
          parsed_data["extraction_source"] = "rules_matched_all"
          return import_and_finalize(parsed_data)
        end

        Rails.logger.info("Enhancing #{unmatched.length} of #{transactions.length} transactions with AI")

        enhanced_result = Ai::PostProcessor.call(
          statement_file: @statement_file,
          transactions: unmatched
        )

        if enhanced_result.success? && enhanced_result.payload["transactions"].present?
          ai_transactions = enhanced_result.payload["transactions"]
          Rails.logger.info("AI enhanced #{ai_transactions.length} transactions")
          parsed_data["transactions"] = matched + ai_transactions
          parsed_data["extraction_source"] = matched.any? ? "rules_and_ai_enhanced_parser" : "ai_enhanced_parser"
        else
          Rails.logger.warn("AI enhancement failed, using parser result without categorization")
        end

        import_and_finalize(parsed_data)
      end

      # record_hits is false because import_and_finalize runs the same rules again and
      # owns the counter — counting here too would double every hit on this path.
      def partition_by_category_rules(transactions)
        result = CategoryRules::Matcher.call(
          user: @statement_file.user,
          transactions: transactions,
          record_hits: false
        )
        return [[], transactions] unless result.success?

        [result.payload[:matched], result.payload[:unmatched]]
      end

      # Full AI extraction path (PII protected)
      def process_with_ai_extraction
        # 1. Redact PII BEFORE any AI call
        Rails.logger.info("Redacting PII from raw text")
        redaction_result = PiiHandler.redact_text(@statement_file, @raw_text)
        redacted_text = redaction_result[:redacted_text]

        # 2. AI extracts AND categorizes in a single call
        Rails.logger.info("AI extraction + categorization (single call)")
        structured_result = Ai::PostProcessor.call(
          statement_file: @statement_file,
          raw_text: redacted_text
        )

        unless structured_result.success?
          Rails.logger.warn("AI processing failed: #{structured_result.errors.full_messages.join(", ")}")
          return structured_result
        end

        structured_data = structured_result.payload

        # Check if AI returned no transactions
        unless has_transactions?(structured_data)
          Rails.logger.info("AI returned no transactions")
          return success_with_no_transactions
        end

        # 3. Restore PII in structured output
        Rails.logger.info("Restoring PII in structured data")
        restored_result = PiiHandler.restore(@statement_file, structured_data)
        return handle_failure("PII restoration failed") unless restored_result.success?

        import_and_finalize(restored_result.payload)
      end

      def has_transactions?(data)
        transactions = data&.dig("transactions") || data&.dig(:transactions)
        transactions.present?
      end
    end
  end
end
