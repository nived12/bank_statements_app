# spec/views/transactions/_transaction_rows_spec.rb
require 'rails_helper'

RSpec.describe "transactions/_transaction_rows", type: :view do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_number: "1234567890") }
  let(:category) { create(:category, name: "MyString", user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:transaction) do
    create(:transaction,
           user: user,
           bank_account: bank_account,
           category: category,
           statement_file: statement_file,
           description: "Test transaction",
           amount: 100.0,
           date: Date.current,
           transaction_type: "variable_expense")
  end

  before do
    # No need to mock current_user for view specs
    assign(:transactions, [ transaction ])
    assign(:page_offset, 0)
  end

  context "with page offset" do
    before do
      assign(:page_offset, 20)
    end

    it "renders transaction rows with correct numbering" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: 20 }

      expect(rendered).to have_content("21") # 20 + 1
    end

    it "renders all transaction information" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: 20 }

      expect(rendered).to have_content("Test")  # short_description truncates "Test transaction" to "Test"
      expect(rendered).to have_content("$100.00")
      expect(rendered).to have_content("Variable expense")
    end

    it "shows bank account information when available" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: 20 }

      expect(rendered).to have_content(bank.name)
      expect(rendered).to have_content("••••7890")
    end

    it "shows category information when available" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: 20 }

      expect(rendered).to have_content(category.name)
    end

    it "includes edit button for each transaction" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: 20 }

      expect(rendered).to have_css('button[onclick*="openEditModal"]')
    end
  end

  context "without page offset" do
    it "renders transaction rows starting from 1" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: nil }

      expect(rendered).to have_content("1")
    end
  end

  context "with statement file" do
    it "shows statement file link when available" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction ], page_offset: 0 }

      expect(rendered).to have_link(href: "/statement_files/#{statement_file.id}")
    end
  end

  context "without category" do
    let(:transaction_without_category) do
      create(:transaction,
             user: user,
             bank_account: bank_account,
             category: nil,
             description: "Test transaction",
             amount: 100.0,
             date: Date.current,
             transaction_type: "variable_expense")
    end

    it "shows no category message when category is missing" do
      render partial: "transactions/transaction_rows", locals: { transactions: [ transaction_without_category ], page_offset: 0 }

      expect(rendered).to have_content(I18n.t('transactions.no_category'))
    end
  end
end
