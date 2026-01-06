# spec/models/bank_account_spec.rb
require "rails_helper"

RSpec.describe BankAccount, type: :model do
  let(:bank) { create(:bank, :bbva) }
  let(:user) { create(:user) }

  let(:bank_account) do
    build(
      :bank_account,
      bank: bank,
      user: user,
      account_number: "1234567890",
      currency: "MXN",
      opening_balance: 1000.50
    )
  end

  let(:bank_account_without_bank) do
    build(
      :bank_account,
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
      expect(bank_account_without_bank.errors[:bank]).to include("Debes seleccionar un banco")
    end

    it "requires a user" do
      bank_account.user = nil
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:user]).to include("es obligatorio")
    end

    it "requires an account number" do
      bank_account.account_number = nil
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:account_number]).to include("es obligatorio")
    end

    it "allows custom_name to be blank" do
      bank_account.custom_name = nil
      expect(bank_account).to be_valid
    end

    it "limits custom_name to 100 characters" do
      bank_account.custom_name = "a" * 101
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:custom_name]).to include("es demasiado largo (máximo 100 caracteres)")
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
    let(:bbva_bank) { Bank.find_by(code: "bbva") || create(:bank, code: "bbva", name: "BBVA Bancomer") }
    let(:bank_account) { create(:bank_account, bank: bbva_bank, user: user, account_number: "1234567890") }

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
      it "returns 'bbva_savings' for BBVA debit accounts" do
        bbva_bank = Bank.find_by(code: "bbva")
        account = create(:bank_account, bank: bbva_bank, user: user, account_type: "debit")
        expect(account.parser_type).to eq("bbva_savings")
      end

      it "returns 'bbva_credit_card' for BBVA credit accounts" do
        bbva_bank = Bank.find_by(code: "bbva")
        account = create(:bank_account, bank: bbva_bank, user: user, account_type: "credit")
        expect(account.parser_type).to eq("bbva_credit_card")
      end

      it "returns 'generic' for generic banks" do
        account = create(:bank_account, bank: generic_bank, user: user)
        expect(account.parser_type).to eq("generic")
      end

      it "returns 'generic' for unsupported banks" do
        unsupported_bank = create(:bank, code: "unknown", name: "Unknown", supported_type: nil)
        account = create(:bank_account, bank: unsupported_bank, user: user)
        expect(account.parser_type).to eq("generic")
      end
    end

    describe "#parser_class" do
      it "returns BbvaSavingsAccount for BBVA debit accounts" do
        bbva_bank = Bank.find_by(code: "bbva")
        account = create(:bank_account, bank: bbva_bank, user: user, account_type: "debit")
        expect(account.parser_class).to eq(PdfParser::BbvaSavingsAccount)
      end

      it "returns BbvaCreditCard for BBVA credit accounts" do
        bbva_bank = Bank.find_by(code: "bbva")
        account = create(:bank_account, bank: bbva_bank, user: user, account_type: "credit")
        expect(account.parser_class).to eq(PdfParser::BbvaCreditCard)
      end

      it "returns AI Post Processor for unsupported banks" do
        account = create(:bank_account, bank: generic_bank, user: user)
        expect(account.parser_class).to eq(Ai::PostProcessor)
      end
    end

    describe "#parsing_strategy" do
      it "returns :hybrid for BBVA accounts" do
        bbva_bank = Bank.find_by(code: "bbva")
        account = create(:bank_account, bank: bbva_bank, user: user, account_type: "debit")
        expect(account.parsing_strategy).to eq(:hybrid)
      end

      it "returns :hybrid for Santander banks" do
        santander_bank = Bank.find_by(code: "santander") || create(:bank, code: "santander", name: "Santander")
        account = create(:bank_account, bank: santander_bank, user: user)
        expect(account.parsing_strategy).to eq(:hybrid)
      end

      it "returns :ai_only for unsupported banks" do
        account = create(:bank_account, bank: generic_bank, user: user)
        expect(account.parsing_strategy).to eq(:ai_only)
      end
    end
  end

  describe "factory traits" do
    it "creates BBVA account with :bbva trait" do
      bbva_bank = Bank.find_by(code: "bbva") || create(:bank, code: "bbva", name: "BBVA Bancomer")
      account = create(:bank_account, bank: bbva_bank, user: user)
      expect(account.bank.code).to eq("bbva")
      expect(account.bank.name).to eq("BBVA Bancomer")
    end

    it "creates Santander account with :santander trait" do
      santander_bank = Bank.find_by(code: "santander") || create(:bank, code: "santander", name: "Santander")
      account = create(:bank_account, bank: santander_bank, user: user)
      expect(account.bank.code).to eq("santander")
      expect(account.bank.name).to eq("Santander")
    end

    it "creates account with custom name using :with_custom_name trait" do
      account = create(:bank_account, :with_custom_name, user: user)
      expect(account.custom_name).to eq("My Personal Account")
    end
  end

  describe "opening balance date validations" do
    it "requires opening_balance_date to be present" do
      bank_account.opening_balance_date = nil
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:opening_balance_date]).to include("es obligatorio")
    end

    it "prevents opening_balance_date from being in the future" do
      bank_account.opening_balance_date = Date.current + 1.day
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:opening_balance_date]).to include("cannot be in the future")
    end

    it "allows opening_balance_date to be today" do
      bank_account.opening_balance_date = Date.current
      expect(bank_account).to be_valid
    end

    it "allows opening_balance_date to be in the past" do
      bank_account.opening_balance_date = Date.current - 1.day
      expect(bank_account).to be_valid
    end
  end

  describe "transaction relevance and balance calculations" do
    let(:opening_balance_date) { Date.new(2025, 1, 15) }
    let(:bank_account_with_date) do
      create(
        :bank_account,
        bank: bank,
        user: user,
        opening_balance: 1000.00,
        opening_balance_date: opening_balance_date
      )
    end

    let!(:relevant_transaction) do
      create(
        :transaction,
        user: user,
        bank_account: bank_account_with_date,
        statement_file: create(:statement_file, user: user, bank_account: bank_account_with_date),
        date: opening_balance_date + 5.days,
        amount: 500.00
      )
    end

    let!(:historical_transaction) do
      create(
        :transaction,
        user: user,
        bank_account: bank_account_with_date,
        statement_file: create(:statement_file, user: user, bank_account: bank_account_with_date),
        date: opening_balance_date - 5.days,
        amount: 200.00
      )
    end

    describe "#effective_balance" do
      it "returns opening balance when date is before opening balance date" do
        balance = bank_account_with_date.effective_balance(opening_balance_date - 1.day)
        expect(balance).to eq(1000.00)
      end

      it "calculates balance including relevant transactions when date is on or after opening balance date" do
        balance = bank_account_with_date.effective_balance(opening_balance_date)
        expect(balance).to eq(1500.00) # 1000.00 + 500.00
      end

      it "calculates balance for future dates" do
        balance = bank_account_with_date.effective_balance(opening_balance_date + 10.days)
        expect(balance).to eq(1500.00) # 1000.00 + 500.00
      end

      it "defaults to current date when no date specified" do
        balance = bank_account_with_date.effective_balance
        expect(balance).to eq(1500.00) # 1000.00 + 500.00
      end
    end

    describe "#relevant_transactions" do
      it "returns transactions on or after opening balance date" do
        relevant = bank_account_with_date.relevant_transactions
        expect(relevant).to include(relevant_transaction)
        expect(relevant).not_to include(historical_transaction)
        expect(relevant.count).to eq(1)
      end

      it "uses the optimized scope for better performance" do
        expect(bank_account_with_date.relevant_transactions.to_sql).to include("date >=")
      end
    end

    describe "#historical_transactions" do
      it "returns transactions before opening balance date" do
        historical = bank_account_with_date.historical_transactions
        expect(historical).to include(historical_transaction)
        expect(historical).not_to include(relevant_transaction)
        expect(historical.count).to eq(1)
      end

      it "uses the optimized scope for better performance" do
        expect(bank_account_with_date.historical_transactions.to_sql).to include("date <")
      end
    end

    describe "edge cases" do
      it "handles account with no transactions" do
        empty_account = create(
          :bank_account,
          bank: bank,
          user: user,
          opening_balance: 500.00,
          opening_balance_date: Date.current
        )

        expect(empty_account.effective_balance).to eq(500.00)
        expect(empty_account.relevant_transactions).to be_empty
        expect(empty_account.historical_transactions).to be_empty
      end

      it "handles transactions exactly on opening balance date" do
        edge_case_transaction = create(
          :transaction,
          user: user,
          bank_account: bank_account_with_date,
          statement_file: create(
            :statement_file, user: user,
            bank_account: bank_account_with_date
          ),
          date: opening_balance_date,
          amount: 100.00
        )

        expect(bank_account_with_date.relevant_transactions).to include(edge_case_transaction)
        expect(bank_account_with_date.historical_transactions).not_to include(edge_case_transaction)

        # Balance should include this transaction
        expect(bank_account_with_date.effective_balance).to eq(1600.00) # 1000.00 + 500.00 + 100.00
      end
    end
  end

  describe "#parser_class" do
    context "when bank supports the account type" do
      let(:supported_bank) { create(:bank, supported_type: 'both') }
      let(:bank_account) { create(:bank_account, bank: supported_bank, account_type: 'credit') }

      it "returns specific parser based on parser_type" do
        allow(bank_account).to receive(:parser_type).and_return('bbva_credit_card')
        expect(bank_account.parser_class).to eq(PdfParser::BbvaCreditCard)
      end

      it "returns Generic parser for unsupported parser types" do
        allow(bank_account).to receive(:parser_type).and_return('unknown_type')
        expect(bank_account.parser_class).to eq(PdfParser::Generic)
      end
    end

    context "when bank does not support the account type" do
      let(:unsupported_bank) { create(:bank, supported_type: 'debit') }
      let(:bank_account) { create(:bank_account, bank: unsupported_bank, account_type: 'credit') }

      it "returns AI Post Processor" do
        expect(bank_account.parser_class).to eq(Ai::PostProcessor)
      end
    end

    context "when bank is completely unsupported" do
      let(:unsupported_bank) { create(:bank, supported_type: nil) }
      let(:bank_account) { create(:bank_account, bank: unsupported_bank, account_type: 'debit') }

      it "returns AI Post Processor" do
        expect(bank_account.parser_class).to eq(Ai::PostProcessor)
      end
    end
  end

  describe "#parsing_strategy" do
    context "when bank supports the account type" do
      let(:supported_bank) { create(:bank, supported_type: 'both') }
      let(:bank_account) { create(:bank_account, bank: supported_bank, account_type: 'credit') }

      it "returns existing strategy based on parser_type" do
        allow(bank_account).to receive(:parser_type).and_return('bbva_credit_card')
        expect(bank_account.parsing_strategy).to eq(:hybrid)
      end

      it "returns ai_first for banorte/banamex" do
        allow(bank_account).to receive(:parser_type).and_return('banorte')
        expect(bank_account.parsing_strategy).to eq(:ai_first)
      end
    end

    context "when bank does not support the account type" do
      let(:unsupported_bank) { create(:bank, supported_type: 'debit') }
      let(:bank_account) { create(:bank_account, bank: unsupported_bank, account_type: 'credit') }

      it "returns ai_only strategy" do
        expect(bank_account.parsing_strategy).to eq(:ai_only)
      end
    end

    context "when bank is completely unsupported" do
      let(:unsupported_bank) { create(:bank, supported_type: nil) }
      let(:bank_account) { create(:bank_account, bank: unsupported_bank, account_type: 'debit') }

      it "returns ai_only strategy" do
        expect(bank_account.parsing_strategy).to eq(:ai_only)
      end
    end
  end
end
