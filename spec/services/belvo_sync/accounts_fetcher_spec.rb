require "rails_helper"

RSpec.describe BelvoSync::AccountsFetcher do
  let(:user) { create(:user) }
  let(:bank) { Bank.find_by(code: "bbva") || create(:bank, code: "bbva", name: "BBVA") }
  let(:belvo_link) { create(:belvo_link, user: user, bank: bank) }

  let(:belvo_accounts) do
    [
      {
        "id" => "acc-belvo-001",
        "number" => "1234567890",
        "name" => "Cuenta BBVA",
        "currency" => "MXN",
        "type" => "checking",
        "balance" => { "current" => 15000.50, "available" => 14500.00 },
        "internal_identification" => "1234567890"
      }
    ]
  end

  let(:mock_client) { instance_double(Belvo::Client) }
  let(:mock_accounts) { instance_double(Belvo::Account) }

  before do
    allow(Belvo::ClientFactory).to receive(:call).and_return(
      ApplicationService::Response.new(success: true, payload: mock_client, errors: nil)
    )
    allow(mock_client).to receive(:accounts).and_return(mock_accounts)
    allow(mock_accounts).to receive(:retrieve).and_return(belvo_accounts)
  end

  describe ".call" do
    it "creates a new bank account" do
      expect {
        described_class.call(belvo_link: belvo_link)
      }.to change(BankAccount, :count).by(1)
    end

    it "sets belvo fields on the new account" do
      described_class.call(belvo_link: belvo_link)
      account = BankAccount.last
      expect(account.belvo_account_id).to eq("acc-belvo-001")
      expect(account.belvo_link).to eq(belvo_link)
      expect(account.bank).to eq(bank)
      expect(account.account_number).to eq("1234567890")
      expect(account.sync_status).to eq("synced")
    end

    it "sets balance from Belvo data" do
      described_class.call(belvo_link: belvo_link)
      expect(BankAccount.last.opening_balance).to eq(15000.50)
    end

    it "maps credit card account type" do
      belvo_accounts.first["type"] = "credit_card"
      described_class.call(belvo_link: belvo_link)
      expect(BankAccount.last.account_type).to eq("credit")
    end

    context "when account already exists (re-sync)" do
      let!(:existing) do
        create(
          :bank_account,
          user: user,
          bank: bank,
          account_number: "1234567890",
          belvo_link: belvo_link,
          belvo_account_id: "acc-belvo-001",
          opening_balance: 10000,
          opening_balance_date: 1.week.ago.to_date
        )
      end

      it "does not create a new account" do
        expect {
          described_class.call(belvo_link: belvo_link)
        }.not_to change(BankAccount, :count)
      end

      it "updates the balance" do
        described_class.call(belvo_link: belvo_link)
        existing.reload
        expect(existing.opening_balance).to eq(15000.50)
      end
    end

    context "when Belvo returns no accounts" do
      before do
        allow(mock_accounts).to receive(:retrieve).and_return([])
      end

      it "creates no bank accounts" do
        expect {
          described_class.call(belvo_link: belvo_link)
        }.not_to change(BankAccount, :count)
      end

      it "returns success with zero count" do
        result = described_class.call(belvo_link: belvo_link)
        expect(result).to be_success
        expect(result.payload).to eq(0)
      end
    end

    it "returns success with account count" do
      result = described_class.call(belvo_link: belvo_link)
      expect(result).to be_success
      expect(result.payload).to eq(1)
    end
  end
end
