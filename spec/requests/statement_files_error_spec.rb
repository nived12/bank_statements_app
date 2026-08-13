# spec/requests/statement_files_error_spec.rb
require "rails_helper"

RSpec.describe "StatementFiles error view", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }

  def error_statement(message)
    create(
      :statement_file,
      user: user,
      bank_account: bank_account,
      status: "error",
      error_message: message
    )
  end

  before do
    sign_in_user(user)
  end

  it "shows the failure heading" do
    get "/statement_files/#{error_statement("Transaction import failed").id}"

    expect(response.body).to include(I18n.t("statement_file_status.processing_failed"))
  end

  it "renders a friendly line for a cause the user can act on" do
    statement_file = error_statement(
      "Vision API error: Gemini stopped early (finishReason: MAX_TOKENS, output 24959 of 65536 max)"
    )

    get "/statement_files/#{statement_file.id}"

    expect(response.body).to include(I18n.t("statement_files.statement_too_long_error"))
  end

  it "does not leak the technical reason to the page" do
    statement_file = error_statement(
      "Vision API error: Gemini stopped early (finishReason: MAX_TOKENS, output 24959 of 65536 max)"
    )

    get "/statement_files/#{statement_file.id}"

    expect(response.body).not_to include("finishReason")
    expect(response.body).not_to include("Gemini")
  end

  it "shows only the generic copy for a reason the user cannot act on" do
    get "/statement_files/#{error_statement("Transaction import failed").id}"

    expect(response.body).to include(I18n.t("statement_file_status.processing_error"))
    expect(response.body).not_to include("Transaction import failed")
  end

  it "still offers the password prompt for a protected PDF" do
    statement_file = error_statement("password_required: PDF is password protected")

    get "/statement_files/#{statement_file.id}"

    expect(response.body).to include(I18n.t("statement_files.password_required_error"))
    expect(response.body).to include(I18n.t("statement_files.enter_pdf_password"))
  end
end
