# spec/requests/statement_files_error_spec.rb
require "rails_helper"

RSpec.describe "StatementFiles error view", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) do
    create(:statement_file,
           user: user,
           bank_account: bank_account,
           status: "error",
           error_message: "Processing Failed")
  end

  before do
    sign_in_user(user)
  end

  it "shows the error message" do
    get "/statement_files/#{statement_file.id}"

    expect(response.body).to include("Processing Failed")
  end
end
