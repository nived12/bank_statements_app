require "rails_helper"

RSpec.describe "Waitlists", type: :request do
  describe "POST /waitlists" do
    let(:valid_params) { { waitlist: { email: "test@example.com" } } }
    let(:invalid_params) { { waitlist: { email: "not-an-email" } } }

    context "with valid email" do
      it "creates a waitlist entry" do
        expect {
          post waitlists_path, params: valid_params
        }.to change(Waitlist, :count).by(1)
      end

      it "captures the current locale" do
        post waitlists_path, params: valid_params
        expect(Waitlist.last.locale).to eq("es")
      end

      it "returns turbo_stream response" do
        post waitlists_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end

    context "with duplicate email" do
      before { create(:waitlist, email: "test@example.com") }

      it "does not create a duplicate entry" do
        expect {
          post waitlists_path, params: valid_params
        }.not_to change(Waitlist, :count)
      end

      it "still returns a success-like response (no error shown)" do
        post waitlists_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid email" do
      it "does not create an entry" do
        expect {
          post waitlists_path, params: invalid_params
        }.not_to change(Waitlist, :count)
      end
    end
  end
end
