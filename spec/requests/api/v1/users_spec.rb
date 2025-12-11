# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let(:user) { create(:user, :confirmed, first_name: "John", last_name: "Doe", email: "john@example.com") }
  let(:access_token) { Auth::GenerateTokensService.call(user).payload[:access_token] }
  let(:auth_headers) { { "Authorization" => "Bearer #{access_token}" } }

  describe "GET /api/v1/user" do
    context "when authenticated" do
      it "returns the current user's profile" do
        get "/api/v1/user", headers: auth_headers

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json["data"]["id"]).to eq(user.id)
        expect(json["data"]["email"]).to eq("john@example.com")
        expect(json["data"]["first_name"]).to eq("John")
        expect(json["data"]["last_name"]).to eq("Doe")
        expect(json["data"]["avatar_url"]).to be_present
      end

      it "includes created_at timestamp" do
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["created_at"]).to be_present
        expect { DateTime.iso8601(json["data"]["created_at"]) }.not_to raise_error
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/user"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "when token is invalid" do
      it "returns 401 unauthorized" do
        get "/api/v1/user", headers: { "Authorization" => "Bearer invalid.token.here" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end

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
          expect do
            patch "/api/v1/user", params: invalid_params, headers: auth_headers
            user.reload
          end.not_to change(user, :first_name)
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
