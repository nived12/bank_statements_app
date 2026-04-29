# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users - Update Password", type: :request do
  let(:password) { "secret123" }
  let(:user) { create(:user, :confirmed, password: password, password_confirmation: password) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "PATCH /api/v1/user/password" do
    context "when authenticated" do
      context "with valid current password and new password" do
        let(:params) do
          {
            user: {
              current_password: password,
              password: "newpassword99",
              password_confirmation: "newpassword99"
            }
          }
        end

        it "returns 200 ok" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          expect(response).to have_http_status(:ok)
        end

        it "returns success message" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["data"]["message"]).to be_present
        end

        it "updates the password" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          user.reload
          expect(user.authenticate("newpassword99")).to be_truthy
        end
      end

      context "with wrong current password" do
        let(:params) do
          {
            user: {
              current_password: "wrongpassword",
              password: "newpassword99",
              password_confirmation: "newpassword99"
            }
          }
        end

        it "returns 422 unprocessable entity" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns INVALID_CURRENT_PASSWORD error code" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("INVALID_CURRENT_PASSWORD")
        end

        it "does not change the password" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          user.reload
          expect(user.authenticate(password)).to be_truthy
        end
      end

      context "with mismatched password confirmation" do
        let(:params) do
          {
            user: {
              current_password: password,
              password: "newpassword99",
              password_confirmation: "differentpassword"
            }
          }
        end

        it "returns 422 unprocessable entity" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns VALIDATION_ERROR code" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      context "with password too short" do
        let(:params) do
          {
            user: {
              current_password: password,
              password: "short",
              password_confirmation: "short"
            }
          }
        end

        it "returns 422 unprocessable entity" do
          patch "/api/v1/user/password", params: params, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "for an OAuth user" do
        let(:oauth_user) { create(:user, :confirmed, :oauth) }
        let(:oauth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(oauth_user).payload[:access_token]}" } }
        let(:oauth_params) do
          { user: { current_password: "anything", password: "newpass99", password_confirmation: "newpass99" } }
        end

        it "returns 422 unprocessable entity" do
          patch "/api/v1/user/password", params: oauth_params, headers: oauth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns OAUTH_ACCOUNT error code" do
          patch "/api/v1/user/password", params: oauth_params, headers: oauth_headers

          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("OAUTH_ACCOUNT")
        end
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        patch "/api/v1/user/password",
          params: { user: { current_password: password, password: "new99", password_confirmation: "new99" } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
