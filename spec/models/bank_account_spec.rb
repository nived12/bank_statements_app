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

    it "requires a bank for non-cash accounts" do
      expect(bank_account_without_bank).not_to be_valid
      expect(bank_account_without_bank.errors[:bank_id]).to include("es obligatorio")
    end

    it "requires a user" do
      bank_account.user = nil
      expect(bank_account).not_to be_valid
      expect(bank_account.errors[:user]).to include("es obligatorio")
    end

    it "requires an account number for non-cash accounts" do
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

    context "uniqueness" do
      before { create(:bank_account, user: user, bank: bank, account_number: "1234567890") }

      it "prevents duplicate account_number for the same user and bank" do
        duplicate = build(:bank_account, user: user, bank: bank, account_number: "1234567890")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:account_number]).to be_present
      end

      it "allows same account_number for a different user" do
        other_user = create(:user)
        account = build(:bank_account, user: other_user, bank: bank, account_number: "1234567890")
        expect(account).to be_valid
      end

      it "allows same account_number at a different bank" do
        other_bank = create(:bank, :santander)
        account = build(:bank_account, user: user, bank: other_bank, account_number: "1234567890")
        expect(account).to be_valid
      end

      it "allows multiple cash accounts for the same user" do
        create(:bank_account, :cash, user: user)
        second_cash = build(:bank_account, :cash, user: user)
        expect(second_cash).to be_valid
      end
    end

    context "cash account" do
      let(:cash_account) do
        build(
          :bank_account, :cash,
          user: user,
          opening_balance: 500.00
        )
      end

      it "is valid without bank_id and account_number" do
        expect(cash_account).to be_valid
      end

      it "still requires opening_balance_date" do
        cash_account.opening_balance_date = nil
        expect(cash_account).not_to be_valid
        expect(cash_account.errors[:opening_balance_date]).to include("es obligatorio")
      end

      it "still requires a user" do
        cash_account.user = nil
        expect(cash_account).not_to be_valid
      end
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
      it "returns transactions after opening balance date" do
        relevant = bank_account_with_date.relevant_transactions
        expect(relevant).to include(relevant_transaction)
        expect(relevant).not_to include(historical_transaction)
        expect(relevant.count).to eq(1)
      end

      it "uses the optimized scope for better performance" do
        expect(bank_account_with_date.relevant_transactions.to_sql).to include("date >")
      end
    end

    # Reproduces the Santander TDD statement of July 2026. The opening balance was
    # entered as the figure the bank app showed on 27-JUL — which already includes
    # that day's -1,000 transfer. Counting the anchor day again subtracted it twice
    # and the account read -552.77 where the statement closed at 447.23.
    describe "the opening balance is the figure at the END of its date" do
      let(:anchor) { Date.new(2026, 7, 27) }
      let(:santander) do
        create(
          :bank_account,
          user: user,
          opening_balance: 562.76,
          opening_balance_date: anchor
        )
      end
      let(:santander_statement) { create(:statement_file, user: user, bank_account: santander) }

      before do
        [
          [Date.new(2026, 7, 27), -1_000.00],
          [Date.new(2026, 7, 30),  46_884.47],
          [Date.new(2026, 7, 30), -47_000.00]
        ].each do |date, amount|
          create(
            :transaction,
            user: user,
            bank_account: santander,
            statement_file: santander_statement,
            date: date,
            amount: amount,
            transaction_type: amount.negative? ? "variable_expense" : "income"
          )
        end
      end

      it "matches the statement's SALDO FINAL DEL PERIODO" do
        expect(santander.effective_balance(Date.new(2026, 7, 31))).to eq(447.23)
      end

      it "does not re-apply activity already baked into the entered figure" do
        expect(santander.relevant_transactions.count).to eq(2)
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
      end

      it "excludes transactions dated exactly on the opening balance date" do
        # The opening balance is the figure at the end of that day, so anything dated
        # on it is already inside the number. Re-applying it double-counts.
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

        expect(bank_account_with_date.relevant_transactions).not_to include(edge_case_transaction)

        expect(bank_account_with_date.effective_balance).to eq(1500.00) # 1000.00 + 500.00
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

  describe "cash account type" do
    let(:cash_account) { create(:bank_account, :cash, user: user, custom_name: "Wallet") }

    describe "enum" do
      it "has cash as a valid account_type with value 'cash'" do
        expect(BankAccount.account_types["cash"]).to eq("cash")
      end

      it "responds to cash? predicate" do
        expect(cash_account.cash?).to be true
      end
    end

    describe "#cash?" do
      it "returns true for cash accounts" do
        expect(cash_account.cash?).to be true
      end

      it "returns false for debit accounts" do
        expect(bank_account).not_to be_cash
      end
    end

    describe "#display_name" do
      it "returns custom_name when present" do
        expect(cash_account.display_name).to eq("Wallet")
      end

      it "returns translated 'Cash' when custom_name is blank" do
        cash_account.custom_name = nil
        expect(cash_account.display_name).to eq(I18n.t("account_type.cash"))
      end
    end

    describe "#bank_display_name" do
      it "returns translated 'Cash'" do
        expect(cash_account.bank_display_name).to eq(I18n.t("account_type.cash"))
      end
    end

    describe "#bank_name" do
      it "returns nil" do
        expect(cash_account.bank_name).to be_nil
      end
    end

    describe "#supported_for_parsing?" do
      it "returns false" do
        expect(cash_account.supported_for_parsing?).to be false
      end
    end

    describe "#parser_type" do
      it "returns 'generic'" do
        expect(cash_account.parser_type).to eq("generic")
      end
    end

    describe "#parser_class" do
      it "returns nil" do
        expect(cash_account.parser_class).to be_nil
      end
    end
  end

  describe "investment account type" do
    let(:investment_account) do
      create(:bank_account, user: user, bank: bank, account_type: "investment")
    end

    it "is a valid account_type" do
      expect(BankAccount.account_types["investment"]).to eq("investment")
      expect(investment_account.investment?).to be true
    end

    it "keeps bank and account number, unlike a cash account" do
      expect(investment_account.bank).to eq(bank)
      expect(investment_account.account_number).to be_present
    end

    # Brokerages are not in the supported-bank list and have no hand-written parser, so
    # they must fall through to the AI path. Writing a parser per broker is exactly what
    # this design avoids — the prompt generalises where a regex would not.
    describe "routing to the AI path" do
      it "routes to the AI post-processor even on an otherwise supported bank" do
        bank.update!(supported_type: "both", active: true)

        expect(bank.supports_account_type?("investment")).to be false
        expect(investment_account.parser_class).to eq(Ai::PostProcessor)
      end
    end

    # A brokerage is worth what its holdings are worth, and market movement never
    # appears as a transaction. Summing the ledger gave $25,007.02 for a real July GBM
    # statement whose front page said $44,857.06.
    describe "#effective_balance" do
      let(:statement_file) do
        create(:statement_file, user: user, bank_account: investment_account)
      end

      def declare(final:, period_end:, file: statement_file, initial: 25_074.62)
        create(
          :statement_financial_summary, statement_file: file,
          initial_balance: initial, final_balance: final,
          statement_period_start: period_end.beginning_of_month,
          statement_period_end: period_end
        )
      end

      before do
        investment_account.update!(opening_balance: 25_074.62, opening_balance_date: Date.new(2026, 6, 30))
        create(
          :transaction, user: user, bank_account: investment_account,
          statement_file: statement_file, amount: -67.60,
          transaction_type: "investment", date: Date.new(2026, 7, 15)
        )
      end

      it "reports the portfolio value the statement declared" do
        declare(final: 44_857.06, period_end: Date.new(2026, 7, 31))

        expect(investment_account.effective_balance).to be_within(0.01).of(44_857.06)
      end

      it "uses the most recent statement" do
        declare(final: 44_857.06, period_end: Date.new(2026, 7, 31))
        newer = create(:statement_file, user: user, bank_account: investment_account)
        declare(final: 51_002.11, period_end: Date.new(2026, 8, 31), file: newer, initial: 44_857.06)

        expect(investment_account.effective_balance).to be_within(0.01).of(51_002.11)
      end

      it "falls back to the ledger when no statement has been uploaded" do
        expect(investment_account.effective_balance).to be_within(0.01).of(25_007.02)
      end

      # extract_decimal records 0.0 for a balance the AI never emitted, and a zero would
      # otherwise win the `||` and show the account as empty.
      it "falls back to the ledger when the declared value is an undeclared zero" do
        declare(final: 0.0, period_end: Date.new(2026, 7, 31))

        expect(investment_account.effective_balance).to be_within(0.01).of(25_007.02)
      end

      describe "#balance_as_of" do
        it "reports the period end of the statement that supplied the value" do
          declare(final: 44_857.06, period_end: Date.new(2026, 7, 31))

          expect(investment_account.balance_as_of).to eq(Date.new(2026, 7, 31))
        end

        it "is nil when the balance came from the ledger instead" do
          expect(investment_account.balance_as_of).to be_nil
        end

        it "is nil for a debit account, whose balance is always current" do
          expect(bank_account.balance_as_of).to be_nil
        end
      end

      it "leaves debit accounts summing the ledger as before" do
        debit = create(
          :bank_account, user: user, bank: bank, account_type: "debit",
          opening_balance: 1_000, opening_balance_date: Date.new(2026, 6, 30)
        )
        debit_statement = create(:statement_file, user: user, bank_account: debit)
        create(
          :statement_financial_summary, statement_file: debit_statement,
          initial_balance: 1_000, final_balance: 99_999,
          statement_period_start: Date.new(2026, 7, 1), statement_period_end: Date.new(2026, 7, 31)
        )
        create(
          :transaction, user: user, bank_account: debit, statement_file: debit_statement,
          amount: 500, transaction_type: "income", date: Date.new(2026, 7, 15)
        )

        expect(debit.effective_balance).to be_within(0.01).of(1_500)
      end
    end
  end

  describe "discard (archive) behaviour" do
    let!(:persisted_account) { create(:bank_account, bank: bank, user: user) }

    it "sets discarded_at on discard" do
      expect { persisted_account.discard }.to change { persisted_account.discarded_at }.from(nil)
      expect(persisted_account).to be_discarded
    end

    it "clears discarded_at on undiscard" do
      persisted_account.discard
      expect { persisted_account.undiscard }.to change { persisted_account.discarded_at }.to(nil)
      expect(persisted_account).not_to be_discarded
    end

    it ".kept excludes discarded accounts" do
      persisted_account.discard
      expect(BankAccount.kept).not_to include(persisted_account)
    end

    it ".kept includes non-discarded accounts" do
      expect(BankAccount.kept).to include(persisted_account)
    end

    it ".discarded returns only discarded accounts" do
      persisted_account.discard
      expect(BankAccount.discarded).to include(persisted_account)
    end
  end
end
