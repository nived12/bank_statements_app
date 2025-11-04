require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user, email: "test@example.com", password: "password123", password_confirmation: "password123") }

  describe "GET /session/new" do
    it "displays the sign in form" do
      get new_session_path
      expect(response).to be_successful
      expect(response.body).to include("Sign In")
    end

    context "when session expired" do
      it "shows expired session message" do
        get new_session_path(expired: true)
        expect(response).to be_successful
        expect(response.body).to include("Your session has expired")
      end
    end
  end

  describe "POST /session" do
    context "with valid credentials" do
      it "signs in the user and redirects to dashboard" do
        post session_path, params: {
          email: user.email,
          password: "password123"
        }

        expect(session[:user_id]).to eq(user.id)
        expect(session[:last_activity]).to be_present
        expect(response).to redirect_to("/dashboard")
      end
    end

    context "with invalid email" do
      it "re-renders the sign in form with error" do
        post session_path, params: {
          email: "wrong@example.com",
          password: "password123"
        }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid email or password")
      end
    end

    context "with invalid password" do
      it "re-renders the sign in form with error" do
        post session_path, params: {
          email: user.email,
          password: "wrongpassword"
        }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid email or password")
      end
    end

    context "with missing parameters" do
      it "handles missing email gracefully" do
        post session_path, params: {
          password: "password123"
        }

        expect(session[:user_id]).to be_nil
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid email or password")
      end
    end
  end

  describe "DELETE /session" do
    before do
      # Sign in user first
      post session_path, params: {
        email: user.email,
        password: "password123"
      }
    end

    it "signs out the user and redirects to sign in" do
      delete session_path

      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to("/session/new")
      # Flash message is displayed via JavaScript, not in HTML body
    end
  end
end
