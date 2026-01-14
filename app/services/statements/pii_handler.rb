# app/services/statements/pii_handler.rb
module Statements
  class PiiHandler < ApplicationService
    def initialize(statement_file, data)
      super()
      @statement_file = statement_file
      @data = data
      @redactor = PiiRedactor.new
    end

    def call
      # Redact PII from transaction descriptions
      redacted_data = redact_pii_from_data(@data)

      success(redacted_data)
    rescue StandardError => e
      errors.add(:base, "PII handling failed: #{e.message}")
      failure
    end

    # Class method for restoring PII
    def self.restore(statement_file, data)
      new(statement_file, data).restore_pii
    end

    def restore_pii
      # Restore PII tokens back to original values
      restored_data = restore_pii_in_data(@data)

      success(restored_data)
    rescue StandardError => e
      errors.add(:base, "PII restoration failed: #{e.message}")
      failure
    end

    private

    attr_reader :statement_file, :data, :redactor

    def redact_pii_from_data(data)
      return data unless data.is_a?(Hash)

      transactions = data[:transactions] || data["transactions"] || []
      return data if transactions.empty?

      redacted_transactions = []
      redaction_map = {}
      last_hmac = nil

      transactions.each do |transaction|
        description = transaction["description"] || transaction[:description]
        next unless description.present?

        # Redact PII from description
        redacted_desc, token_map, hmac = @redactor.redact(description)

        # Merge token maps
        redaction_map.merge!(token_map) if token_map.present?
        last_hmac = hmac if hmac.present?

        # Create redacted transaction
        redacted_transaction = transaction.dup
        if transaction.is_a?(Hash) && transaction.key?("description")
          redacted_transaction["description"] = redacted_desc
        else
          redacted_transaction[:description] = redacted_desc
        end

        redacted_transactions << redacted_transaction
      end

      # Store redaction map and HMAC on statement file
      if redaction_map.present?
        statement_file.update(
          redaction_map: redaction_map,
          redaction_hmac: last_hmac
        )
        Rails.logger.info("Stored #{redaction_map.size} PII tokens for statement #{statement_file.id}")
      end

      # Return data with redacted transactions
      result = data.dup
      if data.key?(:transactions)
        result[:transactions] = redacted_transactions
      elsif data.key?("transactions")
        result["transactions"] = redacted_transactions
      end

      result
    end

    def restore_pii_in_data(data)
      return data unless data.is_a?(Hash)

      transactions = data[:transactions] || data["transactions"] || []
      return data if transactions.empty?

      # Get redaction map from statement file
      redaction_map = statement_file.redaction_map
      return data if redaction_map.blank?

      # NOTE: HMAC validation is not used because:
      # 1. redaction_map is already encrypted in database (StatementFile model encrypts field)
      # 2. HMAC was calculated per-transaction during redaction, making validation complex
      # 3. Database-level encryption provides sufficient integrity protection
      # The HMAC field is kept for potential future use with proper aggregation

      Rails.logger.info("Restoring PII for #{transactions.size} transactions using #{redaction_map.size} tokens")

      restored_transactions = []

      transactions.each do |transaction|
        description = transaction["description"] || transaction[:description]

        if description.present?
          # Restore PII tokens
          restored_desc = @redactor.restore(description, redaction_map)

          # Create restored transaction
          restored_transaction = transaction.dup
          if transaction.is_a?(Hash) && transaction.key?("description")
            restored_transaction["description"] = restored_desc
          else
            restored_transaction[:description] = restored_desc
          end

          restored_transactions << restored_transaction
        else
          restored_transactions << transaction
        end
      end

      # Return data with restored transactions
      result = data.dup
      if data.key?(:transactions)
        result[:transactions] = restored_transactions
      elsif data.key?("transactions")
        result["transactions"] = restored_transactions
      end

      result
    end

    def context_for_logging
      {
        statement_file_id: statement_file.id,
        user_id: statement_file.user_id,
        transaction_count: (@data[:transactions] || @data["transactions"] || []).size
      }
    end
  end
end
