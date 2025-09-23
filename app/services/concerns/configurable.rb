# frozen_string_literal: true

##
# Configurable
# Concern module for configuration access that can be included in services
#
# Usage:
# include Configurable in your service class and you can use:
#   ai_api_available?
#   pii_redaction_enabled?
#   text_chunk_size
#
module Configurable
  private

  def ai_api_available?
    ENV["AI_API_KEY"].present? && ENV["AI_MODEL"].present?
  end

  def pii_redaction_enabled?
    %w[true 1].include?(ENV["PII_REDACTION_ENABLED"])
  end

  def ai_max_retries
    ENV["AI_MAX_RETRIES"]&.to_i || 2
  end

  def ai_retry_delay_base
    ENV["AI_RETRY_DELAY_BASE"]&.to_i || 2
  end

  def text_chunk_size
    ENV["TEXT_CHUNK_SIZE"]&.to_i || 8000
  end

  def transaction_text_chunk_size
    ENV["TRANSACTION_TEXT_CHUNK_SIZE"]&.to_i || 4000
  end

  def ai_batch_size
    ENV["AI_BATCH_SIZE"]&.to_i || 10
  end
end
