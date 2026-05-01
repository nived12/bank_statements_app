# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Devices - Create", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:valid_params) do
    {
      device: {
        push_token: "ExponentPushToken[AbCdEfGhIjKlMnOpQrStUv]",
        platform: "ios"
      }
    }
  end

  describe "POST /api/v1/devices" do
    context "with valid params" do
      it "creates a device and returns 201" do
        post "/api/v1/devices", params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["push_token"]).to eq("ExponentPushToken[AbCdEfGhIjKlMnOpQrStUv]")
        expect(json["data"]["platform"]).to eq("ios")
        expect(json["data"]["active"]).to eq(true)
      end

      it "upserts (reactivates) an existing token" do
        device = create(
          :device, user: user, push_token: "ExponentPushToken[AbCdEfGhIjKlMnOpQrStUv]", platform: "ios",
          active: false
        )

        post "/api/v1/devices", params: valid_params, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(Device.count).to eq(1)
        expect(device.reload.active).to eq(true)
      end

      it "creates device with android platform" do
        params = { device: { push_token: "ExponentPushToken[AndroidToken123]", platform: "android" } }
        post "/api/v1/devices", params: params, headers: auth_headers

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["data"]["platform"]).to eq("android")
      end

      it "creates device with web platform" do
        web_sub = '{"endpoint":"https://fcm.example.com/send/abc","keys":{"p256dh":"key","auth":"auth"}}'
        params = { device: { push_token: web_sub, platform: "web" } }
        post "/api/v1/devices", params: params, headers: auth_headers

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["data"]["platform"]).to eq("web")
      end
    end

    context "with invalid params" do
      it "returns 422 for blank push_token" do
        post "/api/v1/devices", params: { device: { push_token: "", platform: "ios" } }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "returns 422 for invalid platform" do
        post "/api/v1/devices", params: { device: { push_token: "token", platform: "blackberry" } },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "without auth" do
      it "returns 401" do
        post "/api/v1/devices", params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
