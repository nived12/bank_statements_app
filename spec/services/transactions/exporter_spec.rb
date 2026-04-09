require "rails_helper"

RSpec.describe Transactions::Exporter do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:parent_category) { create(:category, user: user, name: "Food") }
  let(:category) { create(:category, user: user, name: "Restaurants", parent: parent_category) }

  let!(:transaction1) do
    create(
      :transaction,
      user: user,
      bank_account: bank_account,
      statement_file: statement_file,
      category: category,
      date: Date.new(2024, 3, 15),
      amount: -25.50,
      transaction_type: "variable_expense",
      description: "Restaurant payment",
      merchant: "Chipotle",
      reference: "REF001"
    )
  end

  let!(:transaction2) do
    create(
      :transaction,
      user: user,
      bank_account: bank_account,
      statement_file: statement_file,
      category: nil,
      date: Date.new(2024, 3, 16),
      amount: 2500.00,
      transaction_type: "income",
      description: "Salary deposit"
    )
  end

  before { Current.user = user }

  describe "#call" do
    let(:transactions) do
      user.transactions
          .includes(:bank_account, category: :parent)
          .order(date: :desc)
    end

    it "returns success with CSV data" do
      result = described_class.call(transactions)

      expect(result).to be_success
      expect(result.payload).to be_a(String)
    end

    it "includes CSV headers" do
      result = described_class.call(transactions)
      csv = CSV.parse(result.payload)
      headers = csv.first

      expect(headers).to include(
        I18n.t("table_headers.date"),
        I18n.t("transactions.bank_name"),
        I18n.t("table_headers.account"),
        I18n.t("table_headers.description"),
        I18n.t("transactions.merchant"),
        I18n.t("transactions.reference"),
        I18n.t("table_headers.amount"),
        I18n.t("table_headers.transaction_type"),
        I18n.t("transactions.category"),
        I18n.t("transactions.parent_category")
      )
    end

    it "includes all transactions" do
      result = described_class.call(transactions)
      csv = CSV.parse(result.payload)

      expect(csv.size).to eq(3) # header + 2 rows
    end

    it "formats transaction data correctly" do
      result = described_class.call(transactions)
      csv = CSV.parse(result.payload)
      row = csv.find { |r| r.include?("Restaurant payment") }

      expect(row).to include(
        "2024-03-15",
        bank_account.custom_name,
        "Restaurant payment",
        "Chipotle",
        "REF001",
        "Restaurants"
      )
      expect(row).to include("Food") # parent category
    end

    it "handles nil category gracefully" do
      result = described_class.call(transactions)
      csv = CSV.parse(result.payload)
      row = csv.find { |r| r.include?("Salary deposit") }

      expect(row[9]).to be_nil # category
      expect(row[10]).to be_nil # parent category
    end

    it "handles empty relation" do
      empty_transactions = user.transactions.none
      result = described_class.call(empty_transactions)

      expect(result).to be_success
      csv = CSV.parse(result.payload)
      expect(csv.size).to eq(1) # header only
    end
  end
end
