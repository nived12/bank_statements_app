require "rails_helper"

RSpec.describe "StatementFiles", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }

  before do
    sign_in_user(user)
  end

  describe "GET /statement_files/new" do
    it "renders the upload form" do
      get "/statement_files/new"

      expect(response).to have_http_status(:ok)
    end

    it "redirects with alert when upload access denied (trial ended)" do
      user.update_columns(trial_ends_at: 1.day.ago)

      get "/statement_files/new"

      expect(response).to redirect_to(statement_files_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /statement_files" do
    let(:cutoff_date) { Time.zone.today }
    let(:params) do
      {
        statement_file: {
          bank_account_id: bank_account.id,
          file: fixture_file_upload("sample.pdf", "application/pdf"),
          cutoff_date: cutoff_date.to_s
        }
      }
    end

    it "creates the record, attaches, enqueues, and redirects" do
      expect {
        post "/statement_files", params: params
      }.to have_enqueued_job(StatementIngestJob)

      expect(response).to redirect_to("/statement_files/#{StatementFile.last.id}")

      statement_file = StatementFile.last
      expect(statement_file.bank_account).to eq(bank_account)
      expect(statement_file.user).to eq(user)
      expect(statement_file.file).to be_attached
      expect(statement_file.cutoff_date).to be_present
    end

    it "converts cutoff_date from local date to UTC" do
      post "/statement_files", params: params

      statement_file = StatementFile.last
      expect(statement_file.cutoff_date).to be_a(ActiveSupport::TimeWithZone)
      # Cutoff date should be at end of day in user's timezone, converted to UTC
      expect(statement_file.cutoff_date.to_date).to eq(cutoff_date)
    end

    it "without a file does not create and returns unprocessable entity" do
      # Ensure bank_account is created before test
      bank_account

      params_without_file = params.deep_dup
      params_without_file[:statement_file].delete(:file)

      expect {
        post "/statement_files", params: params_without_file
      }.not_to change(StatementFile, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "without a cutoff_date does not create and re-renders with 422" do
      # Ensure bank_account is created before test
      bank_account

      params_without_cutoff = params.deep_dup
      params_without_cutoff[:statement_file].delete(:cutoff_date)

      expect {
        post "/statement_files", params: params_without_cutoff
      }.not_to change(StatementFile, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "redirects with alert and does not create when upload access denied (trial ended)" do
      user.update_columns(trial_ends_at: 1.day.ago)

      expect {
        post "/statement_files", params: params
      }.not_to change(StatementFile, :count)

      expect(response).to redirect_to(statement_files_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /statement_files/:id" do
    let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }

    it "shows the statement details" do
      get "/statement_files/#{statement_file.id}"

      expect(response).to have_http_status(:ok)
    end
  end
end
