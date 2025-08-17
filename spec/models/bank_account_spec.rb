# spec/models/bank_account_spec.rb
require "rails_helper"

RSpec.describe BankAccount, type: :model do
  let(:bank) { create(:bank, :bbva) }
  let(:user) { create(:user) }

  let(:bank_account) do
    build(:bank_account,
      bank: bank,
      user: user,
      account_number: "1234567890",
      currency: "MXN",
      opening_balance: 1000.50
    )
  end

  let(:bank_account_without_bank) do
    build(:bank_account,
      bank: nil,
      user: user,
      account_number: "1234",
      currency: "MXN",
      opening_balance: 1000.00
    )
  end

  describe "validations" do
    it "is valid with all attributes" do
      expect(bank_account).to be_valid
    end

    it "requires a bank" do
      expect(bank_account_without_bank).not_to be_valid
      expect(bank_account_without_bank.errors[:bank]).to include("must exist")
    end

    it "requires a user" do
      bank_account.user = nil
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:user]).to include("must exist")
    end

    it "requires an account number" do
      bank_account.account_number = nil
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:account_number]).to include("can't be blank")
    end

    it "allows custom_name to be blank" do
      bank_account.custom_name = nil
      expect(bank_account).to be_valid
    end

    it "limits custom_name to 100 characters" do
      bank_account.custom_name = "a" * 101
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:custom_name]).to include("is too long (maximum is 100 characters)")
    end
  end

  describe "associations" do
    it "belongs to a user" do
      expect(bank_account.user).to eq(user)
    end

    it "belongs to a bank" do
      expect(bank_account.bank).to eq(bank)
    end

    it "has many statement files" do
      expect(bank_account.statement_files).to be_empty
    end

    it "has many transactions" do
      expect(bank_account.transactions).to be_empty
    end
  end

  describe "display methods" do
    let(:bank_account) { create(:bank_account, :bbva, user: user, account_number: "1234567890") }

    describe "#display_name" do
      it "returns custom_name with account number when custom_name is present" do
        bank_account.custom_name = "My Personal Account"
        expect(bank_account.display_name).to eq("My Personal Account • 1234567890")
      end

      it "returns bank name with account number when custom_name is blank" do
        bank_account.custom_name = nil
        expect(bank_account.display_name).to eq("BBVA Bancomer • 1234567890")
      end

      it "returns bank name with account number when custom_name is empty string" do
        bank_account.custom_name = ""
        expect(bank_account.display_name).to eq("BBVA Bancomer • 1234567890")
      end
    end

    describe "#bank_name" do
      it "returns the bank code for internal system logic" do
        expect(bank_account.bank_name).to eq("bbva")
      end
    end

    describe "#bank_display_name" do
      it "returns the bank name for UI display" do
        expect(bank_account.bank_display_name).to eq("BBVA Bancomer")
      end
    end
  end

  describe "parsing support" do
    let(:supported_bank) { create(:bank, :bbva) }
    let(:generic_bank) { create(:bank, :generic) }

    describe "#supported_for_parsing?" do
      it "returns true for supported banks" do
        account = create(:bank_account, bank: supported_bank, user: user)
        expect(account.supported_for_parsing?).to be true
      end

      it "returns false for generic banks" do
        account = create(:bank_account, bank: generic_bank, user: user)
        expect(account.supported_for_parsing?).to be false
      end
    end

    describe "#parser_type" do
      it "returns 'bbva' for BBVA banks" do
        bbva_bank = Bank.find_by(code: "bbva")
        account = create(:bank_account, bank: bbva_bank, user: user)
        expect(account.parser_type).to eq("bbva")
      end

      it "returns 'generic' for generic banks" do
        account = create(:bank_account, bank: generic_bank, user: user)
        expect(account.parser_type).to eq("generic")
      end

      it "returns 'generic' for unsupported banks" do
        unsupported_bank = create(:bank, code: "unknown", name: "Unknown", supported: false)
        account = create(:bank_account, bank: unsupported_bank, user: user)
        expect(account.parser_type).to eq("generic")
      end
    end
  end

  describe "factory traits" do
    it "creates BBVA account with :bbva trait" do
      account = create(:bank_account, :bbva, user: user)
      expect(account.bank.code).to eq("bbva")
      expect(account.bank.name).to eq("BBVA Bancomer")
    end

    it "creates Santander account with :santander trait" do
      account = create(:bank_account, :santander, user: user)
      expect(account.bank.code).to eq("santander")
      expect(account.bank.name).to eq("Santander")
    end

    it "creates account with custom name using :with_custom_name trait" do
      account = create(:bank_account, :with_custom_name, user: user)
      expect(account.custom_name).to eq("My Personal Account")
    end
  end
end
