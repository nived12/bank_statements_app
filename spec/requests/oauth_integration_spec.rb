require 'rails_helper'

RSpec.describe 'OAuth Integration', type: :request do
  describe 'Google OAuth flow' do
    before do
      # Stub ENV variables before making requests (initializer may check them)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GOOGLE_OAUTH_CLIENT_ID').and_return('fake_client_id')
      allow(ENV).to receive(:[]).with('GOOGLE_OAUTH_CLIENT_SECRET').and_return('fake_client_secret')
    end

    describe 'GET /session/new' do
      it 'shows Google OAuth button when credentials are present' do
        get '/session/new'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Continuar con Google')
        expect(response.body).to include('/auth/google_oauth2')
      end
    end

    describe 'POST /auth/google_oauth2' do
      it 'initiates OAuth flow' do
        post '/auth/google_oauth2'
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('accounts.google.com')
      end
    end

    describe 'GET /auth/failure' do
      it 'redirects to login with error message' do
        get '/auth/failure'
        expect(response).to redirect_to('/session/new')
        expect(flash[:alert]).to eq(I18n.t('session.oauth_failed'))
      end
    end
  end
end
