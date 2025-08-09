require "rails_helper"

RSpec.describe "StatementFiles", type: :request do
  let(:bank_account) do
    create(
      :bank_account,
      bank_name: "BBVA",
      account_number: "1234",
      currency: "MXN",
      opening_balance: 0.0
    )
  end

  let(:pdf_path) { Rails.root.join("spec/fixtures/files/sample.pdf") }
  let(:uploaded_pdf) { Rack::Test::UploadedFile.new(pdf_path, "application/pdf") }

  describe "GET /statement_files/new" do
    it "renders the upload form" do
      get "/statement_files/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Upload statement PDF")
    end
  end

  describe "POST /statement_files" do
    before { ActiveJob::Base.queue_adapter = :test }

    context "with valid params" do
      let(:params) do
        { statement_file: { bank_account_id: bank_account.id, file: uploaded_pdf } }
      end

      it "creates the record, attaches, enqueues, and redirects" do
        expect {
          post "/statement_files", params: params
        }.to have_enqueued_job(StatementIngestJob)

        statement = StatementFile.last
        expect(statement.file).to be_attached
        expect(response).to redirect_to("/statement_files/#{statement.id}")
      end
    end

    context "without a file" do
      let(:params) do
        {
          statement_file: {
            bank_account_id: bank_account.id
          }
        }
      end

      it "does not create and re-renders with 422" do
        expect {
          post "/statement_files", params: params
        }.not_to change(StatementFile, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Upload failed")
      end
    end
  end

  describe "GET /statement_files/:id" do
    let(:statement_file) { create(:statement_file, bank_account:) }

    it "shows the statement details" do
      get "/statement_files/#{statement_file.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Statement file")
      expect(response.body).to include(bank_account.display_name)
    end
  end
end
