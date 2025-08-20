# spec/services/file_handling_service_spec.rb
require 'rails_helper'

RSpec.describe FileHandlingService do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }

  describe '.create_temp_file' do
    let(:file_content) { 'test file content' }
    let(:temp_file) { double('tempfile', write: nil, rewind: nil) }

    before do
      allow(Tempfile).to receive(:new).and_return(temp_file)
      allow(statement.file).to receive(:download).and_return(file_content)
    end

    it 'creates a temporary file with PDF extension' do
      described_class.create_temp_file(statement)

      expect(Tempfile).to have_received(:new).with([ 'statement', '.pdf' ], binmode: true)
    end

    it 'writes file content to temp file' do
      described_class.create_temp_file(statement)

      expect(temp_file).to have_received(:write).with(file_content)
    end

    it 'rewinds the temp file' do
      described_class.create_temp_file(statement)

      expect(temp_file).to have_received(:rewind)
    end

    it 'returns the temp file' do
      result = described_class.create_temp_file(statement)

      expect(result).to eq(temp_file)
    end
  end

  describe '.cleanup_temp_file' do
    let(:temp_file) { double('tempfile') }

    context 'when cleanup succeeds' do
      before do
        allow(temp_file).to receive(:close!)
      end

      it 'closes the temp file' do
        described_class.cleanup_temp_file(temp_file)

        expect(temp_file).to have_received(:close!)
      end
    end

    context 'when cleanup fails' do
      before do
        allow(temp_file).to receive(:close!).and_raise(StandardError, 'File error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and does not raise' do
        expect { described_class.cleanup_temp_file(temp_file) }.not_to raise_error

        expect(Rails.logger).to have_received(:error).with('Failed to cleanup temp file: File error')
      end
    end

    context 'when temp_file is nil' do
      it 'does not raise an error' do
        expect { described_class.cleanup_temp_file(nil) }.not_to raise_error
      end
    end
  end
end
