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
        return handle_failure("Vision extraction failed") unless extraction_result.success?

        extracted_data = extraction_result.payload

        # Skip PII handling - AI already saw everything
        # Categorization is included in vision prompt

        import_and_finalize(extracted_data)
      end
    end
  end
end
