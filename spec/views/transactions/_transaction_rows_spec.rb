# spec/views/transactions/_transaction_rows_spec.rb
require "rails_helper"

RSpec.describe "transactions/_transaction_rows", type: :view do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }
  let(:transactions) { create_list(:transaction, 3, user: user, bank_account: bank_account, category: category) }

  before do
    # Simulate user login
    allow(view).to receive(:current_user).and_return(user)
  end

  context "with page offset" do
    it "renders transaction rows with correct numbering" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: transactions, 
        page_offset: 20 
      }

      # Should start numbering from 21 (20 + 1)
      expect(rendered).to include("21")
      expect(rendered).to include("22")
      expect(rendered).to include("23")
    end

    it "renders all transaction information" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: transactions, 
        page_offset: 0 
      }

      transactions.each do |transaction|
        expect(rendered).to include(transaction.description)
        expect(rendered).to include(transaction.amount.to_s)
        expect(rendered).to include(transaction.transaction_type.humanize)
      end
    end

    it "shows bank account information when available" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: transactions, 
        page_offset: 0 
      }

      expect(rendered).to include(bank_account.bank.name)
      expect(rendered).to include("••••#{bank_account.account_number.last(4)}")
    end

    it "shows category information when available" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: transactions, 
        page_offset: 0 
      }

      expect(rendered).to include(category.name)
    end

    it "includes edit button for each transaction" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: transactions, 
        page_offset: 0 
      }

      transactions.each do |transaction|
        expect(rendered).to include("openEditModal('#{transaction.id}')")
      end
    end
  end

  context "without page offset" do
    it "renders transaction rows starting from 1" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: transactions, 
        page_offset: nil 
      }

      # Should start numbering from 1
      expect(rendered).to include("1")
      expect(rendered).to include("2")
      expect(rendered).to include("3")
    end
  end

  context "with statement file" do
    let(:statement_file) { create(:statement_file, user: user) }
    let(:transaction_with_file) do
      create(:transaction, 
        user: user, 
        bank_account: bank_account, 
        category: category,
        statement_file: statement_file
      )
    end

    it "shows statement file link when available" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: [transaction_with_file], 
        page_offset: 0 
      }

      expect(rendered).to include("/statement_files/#{statement_file.id}")
      expect(rendered).to include("statement_file")
    end
  end

  context "without category" do
    let(:transaction_without_category) do
      create(:transaction, 
        user: user, 
        bank_account: bank_account, 
        category: nil
      )
    end

    it "shows no category message when category is missing" do
      render partial: "transactions/transaction_rows", locals: { 
        transactions: [transaction_without_category], 
        page_offset: 0 
      }

      expect(rendered).to include("no_category")
    end
  end
end
