# app/services/statements/handlers/text_without_ai_handler.rb
module Statements
  module Handlers
    class TextWithoutAiHandler < ApplicationService
      include ErrorHandling
      include Concerns::ImportFinalizer

      def initialize(statement_file, raw_text)
        super()
        @statement_file = statement_file
        @raw_text = raw_text
      end

      def call
        Rails.logger.info("Using local-only path (no AI)")

        # Use deterministic parser based on bank
        parser_class = @statement_file.bank_account.parser_class

        # If parser_class is Ai::PostProcessor, we can't use it without AI
        if parser_class == Ai::PostProcessor
          return handle_failure("This bank requires AI processing. Please enable AI to process this statement.")
        end

        Rails.logger.info("Using parser: #{parser_class.name}")
        parser_result = parser_class.call(@raw_text)

        unless parser_result.success?
          Rails.logger.warn("Parser failed: #{parser_result.errors.full_messages.join(", ")}")
          return parser_result
        end

        parsed_data = parser_result.payload
        parsed_data["extraction_source"] ||= "deterministic_parser"

        # Check if parser returned no transactions
        transactions = parsed_data&.dig("transactions") || parsed_data&.dig(:transactions)
        if transactions.blank?
          Rails.logger.info("Parser returned no transactions")
          # For ai_enabled=false, no fallback - just import with empty transactions
        end

        import_and_finalize(parsed_data)
      end
    end
  end
end
