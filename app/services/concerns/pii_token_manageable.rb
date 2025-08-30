# frozen_string_literal: true

##
# PiiTokenManageable
# Concern module for managing PII token restoration from redaction maps
#
# Usage:
# include PiiTokenManageable in your service class and you can use:
#   restored_data = restore_pii_tokens(parsed_data, statement)
#
module PiiTokenManageable
  private

  def restore_pii_tokens(parsed, statement)
    return parsed unless statement.redaction_hmac.present? && statement.redaction_map.present?

    Rails.logger.info("[PII] Restoring tokens from map: #{statement.redaction_map.inspect}")
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
      result = obj.dup
      map.each { |token, original| result.gsub!(token, original.to_s) }
      result
    else
      obj
    end
  end
end
