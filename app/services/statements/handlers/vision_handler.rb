# app/services/statements/handlers/vision_handler.rb
module Statements
  module Handlers
    class VisionHandler < ApplicationService
      include ErrorHandling
      include Concerns::ImportFinalizer

      def initialize(statement_file)
        super()
        @statement_file = statement_file
      end

      def call
        Rails.logger.info("Using vision path (single API call with categorization)")

        # Extract + categorize in ONE call (optimization)
        extraction_result = VisionExtractor.call(@statement_file)

        # Keep the extractor's reason; a generic message leaves the stored
        # error_message useless for diagnosis.
        unless extraction_result.success?
          return handle_failure(extraction_failure_reason(extraction_result))
        end

        extracted_data = extraction_result.payload

        # Skip PII handling - AI already saw everything
        # Categorization is included in vision prompt

        import_and_finalize(extracted_data)
      end

      private

      def extraction_failure_reason(result)
        result.errors&.full_messages&.to_sentence.presence || "Vision extraction failed"
      end
    end
  end
end
