require "rails_helper"

RSpec.describe "StatementFiles", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }

  before do
    sign_in_user(user)
  end

  describe "GET /statement_files" do
    let(:bank2) { create(:bank, name: "santander") }
    let(:bank_account2) { create(:bank_account, user: user, bank: bank2) }

    it "groups files by bank account" do
      create(:statement_file, bank_account: bank_account, user: user)
      create(:statement_file, bank_account: bank_account2, user: user)

      get "/statement_files"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(bank_account.display_name)
      expect(response.body).to include(bank_account2.display_name)
    end

    it "sorts groups by bank account display name" do
      create(:statement_file, bank_account: bank_account2, user: user)
      create(:statement_file, bank_account: bank_account, user: user)

      get "/statement_files"

      expect(response).to have_http_status(:ok)
      bbva_pos = response.body.index(bank_account.display_name)
      santander_pos = response.body.index(bank_account2.display_name)
      expect(bbva_pos).to be < santander_pos
    end

    it "only shows bank accounts that have statement files" do
      create(:statement_file, bank_account: bank_account, user: user)

      get "/statement_files"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(bank_account.display_name)
      expect(response.body).not_to include(bank_account2.display_name)
    end

    it "does not include other users statement files" do
      other_user = create(:user)
      other_account = create(:bank_account, user: other_user, bank: bank)
      other_sf = create(:statement_file, bank_account: other_account, user: other_user)

      get "/statement_files"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_account.display_name)
    end
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
    let(:cutoff_date) { Date.new(2026, 5, 11) }
    let(:request_timezone) { ActiveSupport::TimeZone["America/Mexico_City"] }
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

    it "converts cutoff_date end-of-day in request timezone to UTC" do
      post "/statement_files", params: params

      statement_file = StatementFile.last
      expect(statement_file.cutoff_date).to be_a(ActiveSupport::TimeWithZone)

      expected_utc = request_timezone.parse("#{cutoff_date} 23:59:59").utc
      expect(statement_file.cutoff_date.utc).to eq(expected_utc)
      expect(statement_file.cutoff_date.in_time_zone(request_timezone).to_date).to eq(cutoff_date)
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

  describe "GET /statement_files/:id/status.json" do
    let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, status: "processing") }

    it "returns the current status as JSON" do
      get "/statement_files/#{statement_file.id}/status.json"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
      expect(JSON.parse(response.body)["status"]).to eq("processing")
    end

    it "returns 406 for HTML format" do
      get "/statement_files/#{statement_file.id}/status"

      expect(response).to have_http_status(:not_acceptable)
    end
  end
end
