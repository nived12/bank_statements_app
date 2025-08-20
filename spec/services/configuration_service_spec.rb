# spec/services/configuration_service_spec.rb
require 'rails_helper'

RSpec.describe ConfigurationService do
  describe '.ai_api_available?' do
    context 'when AI provider and API key are present' do
      before do
        allow(ENV).to receive(:[]).with('AI_PROVIDER').and_return('openai')
        allow(ENV).to receive(:[]).with('AI_API_KEY').and_return('sk-12345')
      end

      it 'returns true' do
        expect(described_class.ai_api_available?).to be true
      end
    end

    context 'when AI provider is missing' do
      before do
        allow(ENV).to receive(:[]).with('AI_PROVIDER').and_return(nil)
        allow(ENV).to receive(:[]).with('AI_API_KEY').and_return('sk-12345')
      end

      it 'returns false' do
        expect(described_class.ai_api_available?).to be false
      end
    end

    context 'when AI API key is missing' do
      before do
        allow(ENV).to receive(:[]).with('AI_PROVIDER').and_return('openai')
        allow(ENV).to receive(:[]).with('AI_API_KEY').and_return(nil)
      end

      it 'returns false' do
        expect(described_class.ai_api_available?).to be false
      end
    end
  end

  describe '.pii_redaction_enabled?' do
    context 'when PII_REDACTION_ENABLED is "true"' do
      before do
        allow(ENV).to receive(:[]).with('PII_REDACTION_ENABLED').and_return('true')
      end

      it 'returns true' do
        expect(described_class.pii_redaction_enabled?).to be true
      end
    end

    context 'when PII_REDACTION_ENABLED is "1"' do
      before do
        allow(ENV).to receive(:[]).with('PII_REDACTION_ENABLED').and_return('1')
      end

      it 'returns true' do
        expect(described_class.pii_redaction_enabled?).to be true
      end
    end

    context 'when PII_REDACTION_ENABLED is "false"' do
      before do
        allow(ENV).to receive(:[]).with('PII_REDACTION_ENABLED').and_return('false')
      end

      it 'returns false' do
        expect(described_class.pii_redaction_enabled?).to be false
      end
    end

    context 'when PII_REDACTION_ENABLED is not set' do
      before do
        allow(ENV).to receive(:[]).with('PII_REDACTION_ENABLED').and_return(nil)
      end

      it 'returns false' do
        expect(described_class.pii_redaction_enabled?).to be false
      end
    end
  end

  describe '.ai_max_retries' do
    context 'when AI_MAX_RETRIES is set' do
      before do
        allow(ENV).to receive(:[]).with('AI_MAX_RETRIES').and_return('5')
      end

      it 'returns the configured value' do
        expect(described_class.ai_max_retries).to eq(5)
      end
    end

    context 'when AI_MAX_RETRIES is not set' do
      before do
        allow(ENV).to receive(:[]).with('AI_MAX_RETRIES').and_return(nil)
      end

      it 'returns default value' do
        expect(described_class.ai_max_retries).to eq(2)
      end
    end
  end

  describe '.ai_retry_delay_base' do
    context 'when AI_RETRY_DELAY_BASE is set' do
      before do
        allow(ENV).to receive(:[]).with('AI_RETRY_DELAY_BASE').and_return('3')
      end

      it 'returns the configured value' do
        expect(described_class.ai_retry_delay_base).to eq(3)
      end
    end

    context 'when AI_RETRY_DELAY_BASE is not set' do
      before do
        allow(ENV).to receive(:[]).with('AI_RETRY_DELAY_BASE').and_return(nil)
      end

      it 'returns default value' do
        expect(described_class.ai_retry_delay_base).to eq(2)
      end
    end
  end

  describe '.text_chunk_size' do
    context 'when TEXT_CHUNK_SIZE is set' do
      before do
        allow(ENV).to receive(:[]).with('TEXT_CHUNK_SIZE').and_return('10000')
      end

      it 'returns the configured value' do
        expect(described_class.text_chunk_size).to eq(10000)
      end
    end

    context 'when TEXT_CHUNK_SIZE is not set' do
      before do
        allow(ENV).to receive(:[]).with('TEXT_CHUNK_SIZE').and_return(nil)
      end

      it 'returns default value' do
        expect(described_class.text_chunk_size).to eq(8000)
      end
    end
  end

  describe '.transaction_text_chunk_size' do
    context 'when TRANSACTION_TEXT_CHUNK_SIZE is set' do
      before do
        allow(ENV).to receive(:[]).with('TRANSACTION_TEXT_CHUNK_SIZE').and_return('6000')
      end

      it 'returns the configured value' do
        expect(described_class.transaction_text_chunk_size).to eq(6000)
      end
    end

    context 'when TRANSACTION_TEXT_CHUNK_SIZE is not set' do
      before do
        allow(ENV).to receive(:[]).with('TRANSACTION_TEXT_CHUNK_SIZE').and_return(nil)
      end

      it 'returns default value' do
        expect(described_class.transaction_text_chunk_size).to eq(4000)
      end
    end
  end
end
