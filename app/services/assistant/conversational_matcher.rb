# frozen_string_literal: true

module Assistant
  # Matches a user message against a YAML-defined catalog of conversational
  # phrases (greetings, thanks, identity, capabilities).
  #
  # Returns the intent symbol (e.g. :greeting) or nil if no phrase matches.
  # Pure-Ruby — does NOT call any LLM. Plain class, mirroring IntentRouter.
  #
  # Phrase source: config/assistant/intent_phrases.yml
  # Add new phrases there — no code change required.
  class ConversationalMatcher
    CONFIG_PATH = Rails.root.join("config/assistant/intent_phrases.yml")

    class << self
      def intents
        @intents ||= load_intents
      end

      def reset!
        @intents = nil
      end

      private

      def load_intents
        YAML.load_file(CONFIG_PATH).each_with_object({}) do |(intent, phrases), acc|
          acc[intent.to_sym] = Array(phrases).map { |p| normalize(p) }.reject(&:blank?)
        end
      end

      def normalize(str)
        I18n.transliterate(str.to_s).downcase.strip
      end
    end

    def initialize(message:)
      @normalized = self.class.send(:normalize, message)
    end

    def call
      return nil if @normalized.blank?

      self.class.intents.each do |intent, phrases|
        return intent if phrases.any? { |phrase| word_match?(phrase) }
      end
      nil
    end

    # Convenience for tests and callers that just want the symbol.
    def self.match(message)
      new(message: message).call
    end

    private

    def word_match?(phrase)
      @normalized.match?(/\b#{Regexp.escape(phrase)}\b/)
    end
  end
end
