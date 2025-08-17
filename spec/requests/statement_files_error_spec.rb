# spec/requests/statement_files_error_spec.rb
require "rails_helper"

RSpec.describe "StatementFiles error view", type: :request do
  let(:user) { create(:user) }
  let(:bbva_bank) { Bank.find_by(code: "bbva") }
  let(:bank_account) do
    create(
      :bank_account,
      user: user,
      bank: bbva_bank,
      account_number: "1234",
      currency: "MXN",
      opening_balance: 0.0
    )
  end

  let(:statement_file) do
    create(
      :statement_file,
      user: user,
      bank_account: bank_account,
      status: "error",
      processed_at: Time.current,
      parsed_json: nil
    )
  end

  before do
    sign_in_user(user)
    statement_file.update!(error_message: "No extractable text found.")
  end

  it "shows the error message" do
    get "/statement_files/#{statement_file.id}"
    expect(response.body).to include("Processing Failed")
    expect(response.body).to include("No extractable text found.")
  end
end
