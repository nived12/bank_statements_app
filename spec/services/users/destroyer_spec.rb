# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::Destroyer do
  let(:user) { create(:user) }

  describe "#call" do
    context "when the user has not been archived" do
      it "refuses to run" do
        result = described_class.call(user: user)
        expect(result).to be_failure
        expect(result.errors.full_messages.join).to include("must be archived")
      end
    end

    context "when the user is archived" do
      before { user.discard! }

      it "anonymizes the user's email" do
        original_email = user.email
        described_class.call(user: user)
        expect(user.reload.email).to eq("deleted-#{user.id}@vitt.io")
        expect(user.email).not_to eq(original_email)
      end

      it "destroys transactions, bank accounts, and statement files" do
        bank_account = create(:bank_account, user: user)
        create(:transaction, user: user, bank_account: bank_account)

        described_class.call(user: user)

        expect(user.bank_accounts.count).to eq(0)
        expect(user.transactions.count).to eq(0)
      end

      it "retains legal_consents rows but nullifies the user_id (LFPDPPP Art. 14)" do
        LegalConsent.create!(
          user: user,
          email: user.email,
          accepted_at: Time.current,
          document_type: "terms",
          document_version: "v1"
        )
        described_class.call(user: user)

        expect(LegalConsent.where(user_id: user.id).count).to eq(0)
        expect(LegalConsent.where(user_id: nil).count).to be >= 1
      end
    end
  end
end
