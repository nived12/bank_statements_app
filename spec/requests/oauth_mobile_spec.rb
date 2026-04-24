# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mobile OAuth flow", type: :request do
  # OmniAuth stores request.GET (query string only) in omniauth.params — not POST body.
  # mobile_redirect_uri must therefore appear as a query param on the auth initiation URL.
  let(:mobile_redirect_uri) { "vittio://auth/callback" }
  let(:encoded_uri) { CGI.escape(mobile_redirect_uri) }

  let(:google_auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-uid-123",
      info: {
        email: "mobile@example.com",
        name: "Mobile User",
        given_name: "Mobile",
        family_name: "User",
        image: "https://example.com/avatar.jpg"
      }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = google_auth_hash
    Rack::Attack.cache.store.clear
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  # Initiate OAuth with mobile_redirect_uri as a query param, then follow to callback.
  # OmniAuth stores request.GET in the session; the callback restores it into omniauth.params.
  def initiate_mobile_oauth(redirect_uri: mobile_redirect_uri)
    post "/auth/google_oauth2?mobile_redirect_uri=#{CGI.escape(redirect_uri)}"
    follow_redirect!
  end

  # ---------------------------------------------------------------------------
  # Success path — new user
  # ---------------------------------------------------------------------------
  describe "callback with mobile_redirect_uri (new user)" do
    it "creates a user and redirects to the deep-link URI with JWT tokens" do
      expect { initiate_mobile_oauth }.to change(User, :count).by(1)

      expect(response).to have_http_status(:redirect)
      location = response.location
      expect(location).to start_with("vittio://auth/callback")

      query = URI.decode_www_form(URI.parse(location).query).to_h
      expect(query["access_token"]).to be_present
      expect(query["refresh_token"]).to be_present
      expect(query["expires_in"]).to eq("900")
      expect(query["token_type"]).to eq("Bearer")
      expect(query["error"]).to be_nil
    end

    it "creates an auto-confirmed user" do
      initiate_mobile_oauth
      user = User.find_by!(email: "mobile@example.com")
      expect(user.confirmed?).to be true
    end

    it "does NOT set a cookie session" do
      initiate_mobile_oauth
      expect(session[:user_id]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Success path — existing user linked by email
  # ---------------------------------------------------------------------------
  describe "callback with mobile_redirect_uri (existing email user)" do
    let!(:existing_user) { create(:user, :confirmed, email: "mobile@example.com") }

    it "links OAuth to the existing user without creating a new one" do
      expect { initiate_mobile_oauth }.not_to change(User, :count)

      query = URI.decode_www_form(URI.parse(response.location).query).to_h
      expect(query["access_token"]).to be_present
      expect(query["refresh_token"]).to be_present
    end

    it "updates provider/uid on the existing user" do
      initiate_mobile_oauth
      existing_user.reload
      expect(existing_user.provider).to eq("google_oauth2")
      expect(existing_user.uid).to eq("google-uid-123")
    end
  end

  # ---------------------------------------------------------------------------
  # Success path — returning OAuth user
  # ---------------------------------------------------------------------------
  describe "callback with mobile_redirect_uri (returning OAuth user)" do
    let!(:oauth_user) do
      User.create!(
        first_name: "Mobile", last_name: "User",
        email: "mobile@example.com",
        provider: "google_oauth2", uid: "google-uid-123",
        password: SecureRandom.hex(16),
        confirmed_at: Time.current
      )
    end

    it "signs in and redirects with fresh tokens" do
      initiate_mobile_oauth

      query = URI.decode_www_form(URI.parse(response.location).query).to_h
      expect(query["access_token"]).to be_present
      expect(query["refresh_token"]).to be_present
      expect(query["error"]).to be_nil
    end

    it "does not create a duplicate user" do
      expect { initiate_mobile_oauth }.not_to change(User, :count)
    end
  end

  # ---------------------------------------------------------------------------
  # Token validity — the access token must authenticate API calls
  # ---------------------------------------------------------------------------
  describe "token validity" do
    it "access token works against a protected API endpoint" do
      initiate_mobile_oauth

      query = URI.decode_www_form(URI.parse(response.location).query).to_h
      access_token = query["access_token"]

      get "/api/v1/user", headers: { "Authorization" => "Bearer #{access_token}" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Security — invalid mobile_redirect_uri schemes must be rejected
  # ---------------------------------------------------------------------------
  describe "invalid mobile_redirect_uri" do
    shared_examples "rejects mobile_redirect_uri" do |uri, description|
      it "rejects #{description} and redirects to /session/new instead" do
        post "/auth/google_oauth2?mobile_redirect_uri=#{CGI.escape(uri)}"
        follow_redirect!

        expect(response.location).not_to start_with(uri.split("?").first)
        expect(response).to redirect_to("/session/new")
        expect(session[:user_id]).to be_nil
      end
    end

    include_examples "rejects mobile_redirect_uri", "http://evil.example.com/steal", "http:// scheme"
    include_examples "rejects mobile_redirect_uri", "https://evil.example.com/steal", "https:// scheme"
    include_examples "rejects mobile_redirect_uri", "javascript:alert(1)", "javascript: scheme"
  end

  # ---------------------------------------------------------------------------
  # OAuth failure — mobile_redirect_uri present in env (set by on_failure proc)
  # ---------------------------------------------------------------------------
  describe "oauth_failure action with mobile_redirect_uri" do
    it "redirects to deep-link URI with error param when mobile_redirect_uri is present" do
      # The on_failure proc dispatches to oauth_failure with the env it received.
      # We set omniauth.params in the session to simulate what mock_request_call stored.
      get "/auth/failure",
          params: { message: "access_denied" },
          env: { "omniauth.params" => { "mobile_redirect_uri" => mobile_redirect_uri } }

      expect(response).to have_http_status(:redirect)
      location = response.location
      expect(location).to start_with("vittio://")

      query = URI.decode_www_form(URI.parse(location).query).to_h
      expect(query["error"]).to be_present
      expect(query["access_token"]).to be_nil
    end

    it "falls back to /session/new when no mobile_redirect_uri on failure" do
      get "/auth/failure", params: { message: "access_denied" }
      expect(response).to redirect_to("/session/new")
    end
  end

  # ---------------------------------------------------------------------------
  # Web flow unchanged when mobile_redirect_uri is absent
  # ---------------------------------------------------------------------------
  describe "callback WITHOUT mobile_redirect_uri (web flow)" do
    it "sets cookie session and redirects to dashboard" do
      post "/auth/google_oauth2"
      follow_redirect!

      expect(session[:user_id]).to be_present
      expect(response).to redirect_to("/dashboard")
    end

    it "does NOT include tokens in the redirect location" do
      post "/auth/google_oauth2"
      follow_redirect!

      expect(response.location).not_to include("access_token")
    end
  end
end
