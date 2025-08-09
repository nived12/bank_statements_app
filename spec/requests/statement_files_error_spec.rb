# spec/requests/statement_files_error_spec.rb
require "rails_helper"

RSpec.describe "StatementFiles error view", type: :request do
  let(:bank_account) do
    create(
      :bank_account,
      bank_name: "BBVA",
      account_number: "1234",
      currency: "MXN",
      opening_balance: 0.0
    )
  end

  let(:statement_file) do
    create(
      :statement_file,
      bank_account: bank_account,
      status: "error",
      processed_at: Time.current,
      parsed_json: nil
    )
  end

  before do
    statement_file.update!(error_message: "No extractable text found.")
  end

  it "shows the error message" do
    get "/statement_files/#{statement_file.id}"
    expect(response.body).to include("Processing error:")
    expect(response.body).to include("No extractable text found.")
  end
end
