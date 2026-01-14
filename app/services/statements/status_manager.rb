# app/services/statements/status_manager.rb
module Statements
  class StatusManager < ApplicationService
    def initialize(statement_file, import_result)
      super()
      @statement_file = statement_file
      @import_result = import_result
    end

    def call
      new_status = determine_status
      @statement_file.update(status: new_status)

      Rails.logger.info("Updated statement #{@statement_file.id} status to #{new_status}")
      success(new_status)
    rescue StandardError => e
      errors.add(:base, "Status update failed: #{e.message}")
      failure
    end

    private

    attr_reader :statement_file, :import_result

    def determine_status
      # Check if duplicates were found during import
      duplicates_found = import_result[:duplicates_found] || false

      if duplicates_found
        # Duplicates found - user needs to review in pending_transactions
        :parsed
      else
        # No duplicates - all transactions imported successfully
        :completed
      end
    end

    def context_for_logging
      {
        statement_file_id: statement_file.id,
        user_id: statement_file.user_id,
        duplicates_found: import_result[:duplicates_found]
      }
    end
  end
end
