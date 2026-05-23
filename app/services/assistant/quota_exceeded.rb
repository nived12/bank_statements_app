# frozen_string_literal: true

module Assistant
  class QuotaExceeded < Assistant::Error
    attr_reader :reason, :message_text

    def initialize(reason = :assistant_limit_reached, message_text = nil)
      @reason = reason
      @message_text = message_text
      super(message_text || reason.to_s)
    end
  end
end
