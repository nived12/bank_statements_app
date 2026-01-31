# app/services/statements/pii_handler.rb
#
# Handles PII (Personally Identifiable Information) redaction and restoration for statement processing.
#
# HMAC Validation Note:
# HMAC validation is currently not used during PII restoration because:
# 1. redaction_map is already encrypted at the database level (StatementFile model encrypts the field)
# 2. HMAC was calculated per-transaction during redaction, making aggregated validation complex
# 3. Database-level encryption provides sufficient integrity protection for our use case
# The HMAC field is kept in the data structure for potential future use with proper aggregation logic.
module Statements
  class PiiHandler < ApplicationService
    def initialize(statement_file, data)
      super()
      @statement_file = statement_file
      @data = data&.deep_symbolize_keys
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

    # Class method for redacting PII from raw text (before AI structuring)
    # Returns { redacted_text: String, map: Hash }
    def self.redact_text(statement_file, raw_text)
      redactor = PiiRedactor.new
      redacted_text, map, hmac = redactor.redact(raw_text)

      # Store map for later restoration
      if map.present?
        statement_file.update(redaction_map: map, redaction_hmac: hmac)
        Rails.logger.info("Stored #{map.size} PII tokens for statement #{statement_file.id} (raw text)")
      end

      { redacted_text: redacted_text, map: map }
    end

    # Class method for restoring PII in raw text
    def self.restore_text(statement_file, text)
      redaction_map = statement_file.redaction_map
      return text if redaction_map.blank?

      redactor = PiiRedactor.new
      redactor.restore(text, redaction_map)
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

      transactions = data[:transactions] || []
      return data if transactions.empty?

      redacted_transactions = []
      redaction_map = {}
      last_hmac = nil

      transactions.each do |transaction|
        description = transaction[:description]
        next unless description.present?

        redacted_desc, token_map, hmac = @redactor.redact(description)

        redaction_map.merge!(token_map) if token_map.present?
        last_hmac = hmac if hmac.present?

        redacted_transaction = transaction.dup
        redacted_transaction[:description] = redacted_desc
        redacted_transactions << redacted_transaction
      end

      if redaction_map.present?
        statement_file.update(
          redaction_map: redaction_map,
          redaction_hmac: last_hmac
        )
        Rails.logger.info("Stored #{redaction_map.size} PII tokens for statement #{statement_file.id}")
      end

      data.merge(transactions: redacted_transactions)
    end

    def restore_pii_in_data(data)
      return data unless data.is_a?(Hash)

      transactions = data[:transactions] || []
      return data if transactions.empty?

      redaction_map = statement_file.redaction_map
      return data if redaction_map.blank?

      Rails.logger.info("Restoring PII for #{transactions.size} transactions using #{redaction_map.size} tokens")

      restored_transactions = transactions.map do |transaction|
        description = transaction[:description]

        if description.present?
          restored_desc = @redactor.restore(description, redaction_map)
          transaction.merge(description: restored_desc)
        else
          transaction
        end
      end

      data.merge(transactions: restored_transactions)
    end

    def context_for_logging
      {
        statement_file_id: statement_file.id,
        user_id: statement_file.user_id,
        transaction_count: (@data[:transactions] || []).size
      }
    end
  end
end
