# spec/requests/error_handling_spec.rb
require "rails_helper"

RSpec.describe "Error Handling", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user_with_locale(user)
  end

  describe "RecordNotFound errors" do
        it "renders custom not found page for non-existent bank account" do
      get "/es/bank_accounts/999999/edit"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(I18n.t('errors.not_found.title'))
      expect(response.body).to include(I18n.t('errors.not_found.message'))
      expect(response.body).to include(I18n.t('errors.not_found.back_to_dashboard'))
    end

    it "renders custom not found page for non-existent statement file" do
      get "/es/statement_files/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(I18n.t('errors.not_found.title'))
      expect(response.body).to include(I18n.t('errors.not_found.message'))
    end

        it "renders custom not found page for routing error" do
      get "/es/categories/1"  # This route doesn't exist (categories has except: [:show])

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(I18n.t('errors.not_found.title'))
      expect(response.body).to include(I18n.t('errors.not_found.message'))
    end
  end

  describe "Direct error page routes" do
    it "renders 404 page directly" do
      get "/404"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(I18n.t('errors.not_found.title'))
    end

    it "renders 500 page directly" do
      get "/500"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include(I18n.t('errors.internal_server_error.title'))
    end
  end

  describe "Error page content" do
    it "includes back to dashboard link" do
      get "/404"

      expect(response.body).to include('href="/es/dashboard"')
      expect(response.body).to include(I18n.t('errors.not_found.back_to_dashboard'))
    end

    it "includes go back button" do
      get "/404"

      expect(response.body).to include('onclick="history.back()"')
      expect(response.body).to include(I18n.t('errors.not_found.go_back'))
    end

    it "includes help text" do
      get "/404"

      expect(response.body).to include(I18n.t('errors.not_found.help_text'))
    end
  end

  describe "Error page styling" do
    it "includes Tailwind CSS classes for styling" do
      get "/404"

      expect(response.body).to include('min-h-screen')
      expect(response.body).to include('bg-gradient-to-br')
      expect(response.body).to include('text-center')
    end

    it "includes error icons" do
      get "/404"

      expect(response.body).to include('svg')
      expect(response.body).to include('text-red-600')
    end
  end
end
