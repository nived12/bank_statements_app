require "rails_helper"

RSpec.describe Statements::Handlers::VisionHandler do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) do
    create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :vision_ai)
  end

  describe "extraction failures" do
    it "stores the extractor's own reason on the statement file" do
      failed = instance_double(
        ApplicationService::Response,
        success?: false,
        errors: ActiveModel::Errors.new(statement_file).tap do |e|
          e.add(:base, "Vision API error: Gemini stopped early (finishReason: MAX_TOKENS)")
        end
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(failed)

      described_class.call(statement_file)

      statement_file.reload
      expect(statement_file.status).to eq("error")
      expect(statement_file.error_message).to include("MAX_TOKENS")
    end

    it "falls back to a generic message when the extractor reports no reason" do
      failed = instance_double(
        ApplicationService::Response,
        success?: false,
        errors: ActiveModel::Errors.new(statement_file)
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(failed)

      described_class.call(statement_file)

      expect(statement_file.reload.error_message).to eq("Vision extraction failed")
    end

    it "returns a failure response" do
      failed = instance_double(
        ApplicationService::Response,
        success?: false,
        errors: ActiveModel::Errors.new(statement_file).tap { |e| e.add(:base, "boom") }
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(failed)

      expect(described_class.call(statement_file)).to be_failure
    end
  end
end
