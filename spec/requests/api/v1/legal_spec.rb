# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Legal", type: :request do
  let(:user) { create(:user, :not_consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "POST /api/v1/legal/accept" do
    context "when authenticated" do
      it "returns 200 with consent confirmation" do
        post "/api/v1/legal/accept", headers: auth_headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["consent_accepted"]).to be(true)
        expect(data["version"]).to eq(LegalDocument::CURRENT_VERSION)
        expect(data["accepted_at"]).to be_present
      end

      it "creates audit records for all required documents" do
        expect {
          post "/api/v1/legal/accept", headers: auth_headers
        }.to change(LegalConsent, :count).by(LegalDocument::REQUIRED_DOCUMENTS.length)
      end

      it "updates user consent timestamps" do
        post "/api/v1/legal/accept", headers: auth_headers
        user.reload
        expect(user.terms_accepted_at).to be_present
        expect(user.privacy_accepted_at).to be_present
        expect(user.legal_version_accepted).to eq(LegalDocument::CURRENT_VERSION)
      end

      it "creates audit records for each document type" do
        post "/api/v1/legal/accept", headers: auth_headers
        types = LegalConsent.where(user: user).pluck(:document_type)
        expect(types).to match_array(LegalDocument::REQUIRED_DOCUMENTS)
      end

      it "allows re-acceptance (idempotent — adds new audit row)" do
        post "/api/v1/legal/accept", headers: auth_headers
        expect {
          post "/api/v1/legal/accept", headers: auth_headers
        }.to change(LegalConsent, :count).by(LegalDocument::REQUIRED_DOCUMENTS.length)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "/api/v1/legal/accept"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/legal/status" do
    context "when authenticated" do
      context "when consent is current" do
        before { post "/api/v1/legal/accept", headers: auth_headers }

        it "returns consent_current: true" do
          get "/api/v1/legal/status", headers: auth_headers
          expect(response).to have_http_status(:ok)
          data = response.parsed_body["data"]
          expect(data["consent_current"]).to be(true)
          expect(data["accepted_version"]).to eq(LegalDocument::CURRENT_VERSION)
          expect(data["required_version"]).to eq(LegalDocument::CURRENT_VERSION)
        end
      end

      context "when consent has not been given" do
        it "returns consent_current: false" do
          get "/api/v1/legal/status", headers: auth_headers
          expect(response).to have_http_status(:ok)
          data = response.parsed_body["data"]
          expect(data["consent_current"]).to be(false)
          expect(data["accepted_version"]).to be_nil
        end
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/legal/status"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "consent guard on authenticated endpoints" do
    context "when user has not accepted current terms" do
      it "blocks access with TERMS_NOT_ACCEPTED" do
        get "/api/v1/dashboard", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body.dig("error", "code")).to eq("TERMS_NOT_ACCEPTED")
      end

      it "blocks transactions endpoint" do
        get "/api/v1/transactions", headers: auth_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user has accepted current terms" do
      before { post "/api/v1/legal/accept", headers: auth_headers }

      it "allows access to protected endpoints" do
        get "/api/v1/dashboard", headers: auth_headers
        expect(response).not_to have_http_status(:forbidden)
      end
    end

    context "auth endpoints are not blocked" do
      it "login does not require consent" do
        post "/api/v1/login", params: { email: user.email, password: "secret123" }
        expect(response).not_to have_http_status(:forbidden)
      end
    end
  end
end
