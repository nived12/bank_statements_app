# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LegalConsents", type: :request do
  let(:user) { create(:user, :confirmed, :not_consented) }

  before { sign_in_user(user) }

  describe "GET /legal/consent/new" do
    it "renders the consent form" do
      get new_legal_consent_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /legal/consent" do
    context "with all boxes checked" do
      let(:valid_params) do
        { consent: { terms: "1", privacy: "1", financial_data: "1" } }
      end

      it "redirects to root after acceptance" do
        post legal_consent_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "marks the user as consented" do
        post legal_consent_path, params: valid_params
        expect(user.reload.legal_consent_current?).to be(true)
      end

      it "creates audit records" do
        expect {
          post legal_consent_path, params: valid_params
        }.to change(LegalConsent, :count).by(LegalDocument::REQUIRED_DOCUMENTS.length)
      end
    end
  end
end
