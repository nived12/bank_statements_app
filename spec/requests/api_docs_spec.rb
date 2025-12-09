# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiDocs", type: :request do
  let(:user) { create(:user, email: "allowed@example.com") }
  let(:unauthorized_user) { create(:user, email: "unauthorized@example.com") }

  describe "GET /docs" do
    context "when user is not authenticated" do
      it "redirects to login page" do
        get "/docs"
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when API_DOCS_ALLOWED_EMAILS is not configured" do
      before do
        allow(ENV).to receive(:fetch).with("API_DOCS_ALLOWED_EMAILS", "").and_return("")
        sign_in_user(user)
      end

      it "denies access and redirects to root" do
        get "/docs"
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("errors.unauthorized_api_docs"))
      end
    end

    context "when API_DOCS_ALLOWED_EMAILS is configured" do
      before do
        allow(ENV).to receive(:fetch).with("API_DOCS_ALLOWED_EMAILS", "")
          .and_return("allowed@example.com,another@example.com")
      end

      context "when user email is in whitelist" do
        before { sign_in_user(user) }

        it "grants access and renders the page" do
          get "/docs"
          expect(response).to have_http_status(:success)
          expect(response.body).to include("VITTIO API Documentation")
          expect(response.body).to include("swagger-ui")
        end

        it "displays the logged-in user's email" do
          get "/docs"
          expect(response.body).to include("allowed@example.com")
        end
      end

      context "when user email is not in whitelist" do
        before { sign_in_user(unauthorized_user) }

        it "denies access and redirects to root" do
          get "/docs"
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to eq(I18n.t("errors.unauthorized_api_docs"))
        end
      end

      context "when whitelist contains empty values" do
        before do
          allow(ENV).to receive(:fetch).with("API_DOCS_ALLOWED_EMAILS", "")
            .and_return("allowed@example.com, , ,another@example.com")
          sign_in_user(user)
        end

        it "handles empty values correctly" do
          get "/docs"
          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end
