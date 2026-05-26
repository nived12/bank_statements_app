# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::Archiver do
  let(:user) { create(:user) }

  describe "#call" do
    it "marks the user as discarded" do
      expect { described_class.call(user: user) }.to change { user.reload.discarded? }.from(false).to(true)
    end

    it "rotates the JTI so existing tokens are invalidated" do
      original_jti = user.jti
      described_class.call(user: user)
      expect(user.reload.jti).not_to eq(original_jti)
    end

    it "is idempotent — calling twice does not error" do
      described_class.call(user: user)
      result = described_class.call(user: user)
      expect(result).to be_success
    end

    it "preserves user data (does not destroy transactions or bank accounts)" do
      bank_account = create(:bank_account, user: user)
      create(:transaction, user: user, bank_account: bank_account)

      described_class.call(user: user)

      expect(user.bank_accounts.count).to eq(1)
      expect(user.transactions.count).to eq(1)
    end

    it "frees up the email for a fresh signup" do
      email = user.email
      described_class.call(user: user)

      new_user = User.new(
        email: email,
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User"
      )
      expect(new_user).to be_valid
    end
  end
end
