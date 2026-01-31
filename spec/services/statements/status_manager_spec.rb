# spec/services/statements/status_manager_spec.rb
require "rails_helper"

RSpec.describe Statements::StatusManager do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, status: :processing) }

  describe "#call" do
    context "when no duplicates are found" do
      let(:import_result) { { duplicates_found: false } }

      it "sets status to completed" do
        described_class.call(statement_file, import_result)

        expect(statement_file.reload.status).to eq("completed")
      end

      it "returns success with status" do
        result = described_class.call(statement_file, import_result)

        expect(result).to be_success
        expect(result.payload).to eq(:completed)
      end
    end

    context "when duplicates are found" do
      let(:import_result) { { duplicates_found: true } }

      it "sets status to parsed" do
        described_class.call(statement_file, import_result)

        expect(statement_file.reload.status).to eq("parsed")
      end

      it "returns success with status" do
        result = described_class.call(statement_file, import_result)

        expect(result).to be_success
        expect(result.payload).to eq(:parsed)
      end
    end

    context "when duplicates_found is nil" do
      let(:import_result) { {} }

      it "defaults to completed status" do
        described_class.call(statement_file, import_result)

        expect(statement_file.reload.status).to eq("completed")
      end
    end
  end
end
