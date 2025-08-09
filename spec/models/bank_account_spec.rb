# spec/models/bank_account_spec.rb
require "rails_helper"

RSpec.describe BankAccount, type: :model do
  let(:bank_account) do
    build(:bank_account,
      bank_name: "BBVA",
      account_number: "1234567890",
      currency: "MXN",
      opening_balance: 1000.50
    )
  end

  let(:bank_account_without_name) do
    build(:bank_account,
      bank_name: nil,
      account_number: "1234",
      currency: "MXN",
      opening_balance: 1000.00
    )
  end

  it "is valid with all attributes" do
    expect(bank_account).to be_valid
  end

  it "is invalid without a bank_name" do
    expect(bank_account_without_name).not_to be_valid
    expect(bank_account_without_name.errors[:bank_name]).to be_present
  end
end
