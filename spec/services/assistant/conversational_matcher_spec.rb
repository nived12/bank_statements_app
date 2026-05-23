# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::ConversationalMatcher do
  before { described_class.reset! }

  describe ".match" do
    {
      greeting: [
        "hola",
        "Hola, ¿cómo estás?",
        "Hi",
        "Hello there",
        "buenos días",
        "Buenas noches",
        "¿qué onda?",
        "Good morning Vittbot"
      ],
      thanks: [
        "gracias",
        "muchas gracias!",
        "thanks",
        "thank you",
        "ty"
      ],
      identity: [
        "¿quién eres?",
        "Quién eres tú",
        "¿eres ChatGPT?",
        "are you ChatGPT?",
        "are you human",
        "are you AI"
      ],
      capabilities: [
        "¿qué puedes hacer?",
        "ayuda",
        "help",
        "what can you do",
        "how do I use this",
        "¿cómo funcionas?"
      ]
    }.each do |intent, messages|
      messages.each do |msg|
        it "matches #{msg.inspect} as #{intent}" do
          expect(described_class.match(msg)).to eq(intent)
        end
      end
    end

    it "does not match phrases as substrings of other words" do
      # "hola" must not match inside "ahorros"
      expect(described_class.match("Quiero saber sobre ahorros")).to be_nil
      # "ty" must not match inside "ayuda" only at word boundary — but ayuda IS a capabilities phrase
      expect(described_class.match("Mostly curious about my taxes")).to be_nil
    end

    it "returns nil for finance questions" do
      expect(described_class.match("¿Cuál es mi saldo?")).to be_nil
      expect(described_class.match("¿Cuánto gasté este mes?")).to be_nil
    end

    it "returns nil for off-topic questions" do
      expect(described_class.match("raíz cuadrada de 144")).to be_nil
      expect(described_class.match("tell me a joke")).to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.match("")).to be_nil
      expect(described_class.match("   ")).to be_nil
    end

    it "is case insensitive and accent insensitive" do
      expect(described_class.match("HOLA")).to eq(:greeting)
      expect(described_class.match("Buenós días")).to eq(:greeting)
    end
  end

  describe ".intents" do
    it "loads all four conversational intents from YAML" do
      expect(described_class.intents.keys).to contain_exactly(
        :greeting, :thanks, :identity, :capabilities
      )
    end

    it "stores normalized phrases (lowercase, transliterated)" do
      expect(described_class.intents[:greeting]).to include("hola", "buenos dias", "good morning")
    end
  end
end
