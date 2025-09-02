# app/models/concerns/pii_handling_concern.rb
module PiiHandlingConcern
  extend ActiveSupport::Concern

  def apply_pii_redaction(text, statement)
    return text unless pii_redaction_enabled?

    redacted, map, hmac = PiiRedactor.new.redact(text)

    # Ensure the redaction_map is properly set
    if map.present?
      statement.update!(redaction_map: map, redaction_hmac: hmac)
    else
      # If no PII was found, set empty map but still set the fields
      statement.update!(redaction_map: {}, redaction_hmac: hmac)
    end

    redacted
  rescue => e
    handle_pii_error(statement, e)
    raise
  end

  def restore_pii_tokens(parsed, statement)
    return parsed unless pii_redaction_enabled? && statement.redaction_hmac.present? && statement.redaction_map.present?

    restored = restore_tokens_deep(parsed, statement.redaction_map)
    Rails.logger.info("[PII] Token restoration completed")
    restored
  rescue => e
    Rails.logger.error("[PII] Token restoration error: #{e.message}")
    raise RuntimeError, "PII token restoration failed: #{e.message}"
  end

  def restore_tokens_deep(obj, map)
    case obj
    when Hash
      obj.transform_values { |v| restore_tokens_deep(v, map) }
    when Array
      obj.map { |v| restore_tokens_deep(v, map) }
    when String
      # Replace tokens within the string, not the entire string
      result = obj.dup
      map.each { |token, original| result.gsub!(token, original.to_s) }
      result
    else
      obj
    end
  end
end
