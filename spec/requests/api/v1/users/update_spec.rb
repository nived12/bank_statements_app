# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users - Update", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "PATCH /api/v1/user" do
    context "when authenticated" do
      context "with valid parameters" do
        let(:valid_params) do
          {
            user: {
              first_name: "Jane",
              last_name: "Smith"
            }
          }
        end

        it "updates the user's profile" do
          patch "/api/v1/user", params: valid_params, headers: auth_headers

          expect(response).to have_http_status(:success)

          user.reload
          expect(user.first_name).to eq("Jane")
          expect(user.last_name).to eq("Smith")
        end

        it "returns the updated user data" do
          patch "/api/v1/user", params: valid_params, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["data"]["first_name"]).to eq("Jane")
          expect(json["data"]["last_name"]).to eq("Smith")
        end

        it "updates avatar_url" do
          patch "/api/v1/user",
            params: { user: { avatar_url: "https://example.com/new-avatar.jpg" } },
            headers: auth_headers

          expect(response).to have_http_status(:success)

          user.reload
          expect(user.avatar_url).to eq("https://example.com/new-avatar.jpg")
        end
      end

      context "with invalid parameters" do
        let(:invalid_params) do
          {
            user: {
              first_name: "",
              last_name: ""
            }
          }
        end

        it "returns 422 unprocessable entity" do
          patch "/api/v1/user", params: invalid_params, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns validation errors" do
          patch "/api/v1/user", params: invalid_params, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(json["error"]["message"]).to eq("User profile could not be updated")
          expect(json["error"]["details"]).to be_an(Array)
          expect(json["error"]["details"].length).to be > 0
        end

        it "does not update the user" do
          expect {
            patch "/api/v1/user", params: invalid_params, headers: auth_headers
            user.reload
          }.not_to change(user, :first_name)
        end

        it "rejects invalid avatar_url format" do
          patch "/api/v1/user",
            params: { user: { avatar_url: "not-a-valid-url" } },
            headers: auth_headers

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(json["error"]["details"]).to be_an(Array)
          expect(json["error"]["details"].first["field"]).to eq("avatar_url")
        end

        it "accepts valid HTTP/HTTPS avatar_url" do
          patch "/api/v1/user",
            params: { user: { avatar_url: "https://example.com/avatar.jpg" } },
            headers: auth_headers

          expect(response).to have_http_status(:success)
          user.reload
          expect(user.avatar_url).to eq("https://example.com/avatar.jpg")
        end
      end

      context "with empty params" do
        it "returns 400 bad request when user param is missing" do
          patch "/api/v1/user", params: {}, headers: auth_headers

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("PARAMETER_MISSING")
        end
      end

      context "with unpermitted params" do
        it "ignores email updates" do
          original_email = user.email

          patch "/api/v1/user",
            params: { user: { email: "newemail@example.com" } },
            headers: auth_headers

          user.reload
          expect(user.email).to eq(original_email)
        end

        it "ignores password updates" do
          patch "/api/v1/user",
            params: { user: { password: "newpassword123" } },
            headers: auth_headers

          expect(response).to have_http_status(:success)
        end

        it "ignores id updates" do
          original_id = user.id

          patch "/api/v1/user",
            params: { user: { id: 99999, first_name: "Jane" } },
            headers: auth_headers

          user.reload
          expect(user.id).to eq(original_id)
          expect(user.first_name).to eq("Jane")
        end

        it "ignores created_at updates" do
          original_created_at = user.created_at

          patch "/api/v1/user",
            params: { user: { created_at: 1.year.ago, first_name: "Jane" } },
            headers: auth_headers

          user.reload
          expect(user.created_at).to be_within(1.second).of(original_created_at)
          expect(user.first_name).to eq("Jane")
        end
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        patch "/api/v1/user", params: { user: { first_name: "Jane" } }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end
end
