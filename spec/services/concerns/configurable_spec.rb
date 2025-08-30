# frozen_string_literal: true

require "rails_helper"

RSpec.describe Configurable do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include Configurable
    end
  end

  let(:test_instance) { test_class.new }

  before do
    # Reset environment variables for testing
    ENV.delete("AI_PROVIDER")
    ENV.delete("AI_API_KEY")
    ENV.delete("PII_REDACTION_ENABLED")
    ENV.delete("AI_MAX_RETRIES")
    ENV.delete("AI_RETRY_DELAY_BASE")
    ENV.delete("TEXT_CHUNK_SIZE")
    ENV.delete("TRANSACTION_TEXT_CHUNK_SIZE")
  end

  describe "#ai_api_available?" do
    it "returns false when AI_PROVIDER is not set" do
      ENV["AI_API_KEY"] = "test_key"
      expect(test_instance.send(:ai_api_available?)).to be false
    end

    it "returns false when AI_API_KEY is not set" do
      ENV["AI_PROVIDER"] = "openai"
      expect(test_instance.send(:ai_api_available?)).to be false
    end

    it "returns true when both AI_PROVIDER and AI_API_KEY are set" do
      ENV["AI_PROVIDER"] = "openai"
      ENV["AI_API_KEY"] = "test_key"
      expect(test_instance.send(:ai_api_available?)).to be true
    end

    it "returns false when both are empty" do
      expect(test_instance.send(:ai_api_available?)).to be false
    end
  end

  describe "#pii_redaction_enabled?" do
    it "returns true when PII_REDACTION_ENABLED is 'true'" do
      ENV["PII_REDACTION_ENABLED"] = "true"
      expect(test_instance.send(:pii_redaction_enabled?)).to be true
    end

    it "returns true when PII_REDACTION_ENABLED is '1'" do
      ENV["PII_REDACTION_ENABLED"] = "1"
      expect(test_instance.send(:pii_redaction_enabled?)).to be true
    end

    it "returns false when PII_REDACTION_ENABLED is 'false'" do
      ENV["PII_REDACTION_ENABLED"] = "false"
      expect(test_instance.send(:pii_redaction_enabled?)).to be false
    end

    it "returns false when PII_REDACTION_ENABLED is not set" do
      expect(test_instance.send(:pii_redaction_enabled?)).to be false
    end
  end

  describe "#ai_max_retries" do
    it "returns default value when AI_MAX_RETRIES is not set" do
      expect(test_instance.send(:ai_max_retries)).to eq(2)
    end

    it "returns parsed integer when AI_MAX_RETRIES is set" do
      ENV["AI_MAX_RETRIES"] = "5"
      expect(test_instance.send(:ai_max_retries)).to eq(5)
    end

    it "handles invalid values gracefully" do
      ENV["AI_MAX_RETRIES"] = "invalid"
      expect(test_instance.send(:ai_max_retries)).to eq(0)
    end
  end

  describe "#ai_retry_delay_base" do
    it "returns default value when AI_RETRY_DELAY_BASE is not set" do
      expect(test_instance.send(:ai_retry_delay_base)).to eq(2)
    end

    it "returns parsed integer when AI_RETRY_DELAY_BASE is set" do
      ENV["AI_RETRY_DELAY_BASE"] = "10"
      expect(test_instance.send(:ai_retry_delay_base)).to eq(10)
    end
  end

  describe "#text_chunk_size" do
    it "returns default value when TEXT_CHUNK_SIZE is not set" do
      expect(test_instance.send(:text_chunk_size)).to eq(8000)
    end

    it "returns parsed integer when TEXT_CHUNK_SIZE is set" do
      ENV["TEXT_CHUNK_SIZE"] = "4000"
      expect(test_instance.send(:text_chunk_size)).to eq(4000)
    end
  end

  describe "#transaction_text_chunk_size" do
    it "returns default value when TRANSACTION_TEXT_CHUNK_SIZE is not set" do
      expect(test_instance.send(:transaction_text_chunk_size)).to eq(4000)
    end

    it "returns parsed integer when TRANSACTION_TEXT_CHUNK_SIZE is set" do
      ENV["TRANSACTION_TEXT_CHUNK_SIZE"] = "2000"
      expect(test_instance.send(:transaction_text_chunk_size)).to eq(2000)
    end
  end
end
