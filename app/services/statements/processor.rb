# app/services/statements/processor.rb
#
# Unified statement processor with configurable processing strategies.
#
# Processing Strategies:
# - parser_only: Use deterministic parser only (no AI, local processing)
# - text_with_ai: Text extraction + AI fallback → Vision fallback if no transactions
# - vision_ai: Skip text extraction, go directly to Vision API
#
module Statements
  class Processor < ApplicationService
    include ErrorHandling
    include FileHandling

    def initialize(statement_file_id)
      super()
      @statement_file = StatementFile.find(statement_file_id)
    end

    def call
      Rails.logger.info("Processing statement #{@statement_file.id}, strategy=#{@statement_file.processing_strategy}")

      @statement_file.update(status: :processing)

      case @statement_file.processing_strategy
      when "vision_ai"
        Rails.logger.info("Vision AI strategy, skipping text extraction")
        process_with_vision
      when "text_with_ai"
        process_text_first_with_ai_fallback
      when "parser_only"
        process_parser_only
      else
        handle_failure("Unknown processing strategy: #{@statement_file.processing_strategy}")
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      handle_failure("Database error: #{e.message}")
    rescue StandardError => e
      handle_failure("Processing failed: #{e.message}")
    end

    private

    attr_reader :statement_file

    # ============================================
    # TEXT EXTRACTION
    # ============================================

    def extract_with_text
      temp_file = create_temp_file(@statement_file)
      text = TextExtractor.extract_text_layer(temp_file.path)

      if TextExtractor.valid_text?(text)
        Rails.logger.info("Text extraction successful (#{text.length} chars)")
        { text: text }
      else
        Rails.logger.info("Text extraction failed or invalid")
        nil
      end
    ensure
      cleanup_temp_file(temp_file)
    end

    # ============================================
    # PROCESSING STRATEGIES
    # ============================================

    def process_text_first_with_ai_fallback
      text_data = extract_with_text

      if text_data
        result = Handlers::TextWithAiHandler.call(@statement_file, text_data[:text])

        # Fallback to vision if no transactions found
        if no_transactions?(result)
          Rails.logger.info("Text extraction yielded no transactions, falling back to vision")
          return process_with_vision
        end

        result
      else
        # Text extraction failed → Vision fallback
        Rails.logger.info("Text extraction failed, using vision path")
        process_with_vision
      end
    end

    def process_parser_only
      text_data = extract_with_text

      if text_data
        Handlers::TextWithoutAiHandler.call(@statement_file, text_data[:text])
      else
        handle_failure(
          "Cannot process this PDF without AI. " \
          "Please select an AI processing option or upload a text-based PDF."
        )
      end
    end

    def process_with_vision
      Handlers::VisionHandler.call(@statement_file)
    end

    # ============================================
    # SHARED HELPERS
    # ============================================

    def no_transactions?(result)
      return true unless result.is_a?(ApplicationService::Response) && result.success?

      # Check for explicit no_transactions flag
      return true if result.payload.is_a?(Hash) && result.payload[:no_transactions]

      # If payload is a StatementFile, we have transactions (they were imported)
      return false if result.payload.is_a?(StatementFile)

      transactions = result.payload&.dig(:transactions) || result.payload&.dig("transactions")
      transactions.blank?
    end

    def handle_failure(message)
      log_error(
        StandardError.new(message),
        context: "Statement processing",
        data: context_for_logging
      )

      @statement_file.update(
        status: :error,
        error_message: message,
        processed_at: Time.current
      )

      errors.add(:base, message)
      failure
    end

    def context_for_logging
      {
        statement_file_id: @statement_file.id,
        bank_account: @statement_file.bank_account&.bank_name,
        user_id: @statement_file.user_id,
        processing_strategy: @statement_file.processing_strategy
      }
    end
  end
end
