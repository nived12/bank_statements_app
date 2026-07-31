# frozen_string_literal: true

require "rails_helper"

# The Support URL submitted to App Store Connect and Play Console must always
# resolve. A 404 here is an App Store Review Guideline 1.5 rejection.
RSpec.describe "Support", type: :request do
  describe "GET /support" do
    it "renders successfully without authentication" do
      get support_path

      expect(response).to have_http_status(:ok)
    end

    it "does not redirect to the legal consent gate" do
      get support_path

      expect(response).not_to have_http_status(:redirect)
    end

    it "shows the support email address" do
      get support_path

      expect(response.body).to include("support@vitt.io")
    end

    it "renders both Spanish and English copy for the client-side toggle" do
      get support_path

      expect(response.body).to include("data-lang-es")
      expect(response.body).to include("data-lang-en")
    end

    it "defaults to Spanish and honors ?locale=en" do
      get support_path
      expect(response.body).to include("Soporte — Vittio")

      get support_path(locale: "en")
      expect(response.body).to include("Support — Vittio")
    end

    it "links to the legal pages reviewers check" do
      get support_path

      expect(response.body).to include(legal_privacy_path)
      expect(response.body).to include(legal_terms_path)
    end
  end
end
