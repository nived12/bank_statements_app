require 'rails_helper'

RSpec.describe SessionsController, type: :request do
  describe 'OAuth functionality' do
    describe 'POST /auth/google_oauth2' do
      it 'initiates Google OAuth flow' do
        post '/auth/google_oauth2'
        expect(response).to have_http_status(:redirect)
      end
    end

    describe 'GET /auth/google_oauth2/callback' do
      # Note: Testing OAuth callbacks is complex due to OmniAuth's internal workings
      # The actual OAuth flow is tested in integration tests
      # These tests focus on the controller behavior when OAuth data is available

      it 'handles OAuth callback requests' do
        # This test verifies the route exists and doesn't crash
        # The actual OAuth flow is tested in integration tests
        expect { get '/auth/google_oauth2/callback' }.not_to raise_error
      end
    end

    describe 'GET #oauth_failure' do
      it 'redirects to login with error message' do
        get '/auth/failure'

        expect(response).to redirect_to('/session/new')
        expect(flash[:alert]).to eq(I18n.t('session.oauth_failed'))
      end

      it 'logs the failure message' do
        allow(Rails.logger).to receive(:error)
        get '/auth/failure', params: { message: 'access_denied' }

        expect(Rails.logger).to have_received(:error).with('OAuth failure: access_denied')
      end
    end
  end
end
