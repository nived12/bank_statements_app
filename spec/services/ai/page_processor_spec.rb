# spec/services/ai/page_processor_spec.rb
require 'rails_helper'

RSpec.describe Ai::PageProcessor, type: :service do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, supported_type: nil) } # Unsupported bank
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_type: 'credit') }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:categories) { user.categories }
  let(:file_path) { Rails.root.join('spec/fixtures/files/sample.pdf') }
  let(:client) { instance_double(Ai::Client) }

  before do
    # Create a sample PDF file for testing
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "%PDF-1.4\n%…\n%%EOF\n") unless File.exist?(file_path)

    # Create some categories for the user
    create(:category, user: user, name: "Sin Categorizar")
    create(:category, user: user, name: "Comida")

    allow(Ai::Client).to receive(:new).and_return(client)
    allow(client).to receive(:chat).and_return('{"transactions": [], "financial_summaries": []}')
  end

  after do
    File.delete(file_path) if File.exist?(file_path)
  end

  describe '#call_with_text' do
    context 'when text processing succeeds' do
      before do
        # Mock the AI client to return success
        allow_any_instance_of(Ai::GeminiClient).to receive(:chat).and_return(
          '{"transactions": [{"date": "2024-01-01", "amount": "100.00", "description": "Test transaction"}], "financial_summaries": [{"type": "balance", "amount": "1000.00"}], "opening_balance": "900.00", "closing_balance": "1000.00"}'
        )
      end

      it 'processes text and returns results' do
        text_data = { text: "Test bank statement text" }
        
        # Mock the AI client to return a simple response
        allow_any_instance_of(Ai::GeminiClient).to receive(:chat).and_return(
          '{"transactions": [{"date": "2024-01-01", "amount": "100.00", "description": "Test transaction"}], "financial_summaries": [{"type": "balance", "amount": "1000.00"}], "opening_balance": "900.00", "closing_balance": "1000.00"}'
        )
        
        result = described_class.new(statement_file: statement_file).call_with_text(text_data)

        expect(result.success?).to be true
        expect(result.payload["transactions"]).to be_present
        expect(result.payload["transactions"].length).to eq(1)
        expect(result.payload["financial_summaries"]).to eq([])
        expect(result.payload["opening_balance"]).to eq("900.00")
        expect(result.payload["closing_balance"]).to eq("1000.00")
      end
    end

    context 'when text processing fails' do
      before do
        allow_any_instance_of(Ai::GeminiClient).to receive(:chat).and_raise(StandardError.new("AI processing failed"))
      end

      it 'returns failure with error message' do
        text_data = { text: "Test bank statement text" }
        result = described_class.new(statement_file: statement_file).call_with_text(text_data)

        expect(result.failure?).to be true
      end
    end
  end

end
