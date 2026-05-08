# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Devices - Destroy", type: :request do
  let(:user) { create(:user, :consented) }
  let(:other_user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let!(:device) { create(:device, user: user, push_token: "ExponentPushToken[TestToken]") }

  describe "DELETE /api/v1/devices/:push_token" do
    it "deletes the device and returns 204" do
      delete "/api/v1/devices/#{ERB::Util.url_encode(device.push_token)}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(Device.find_by(id: device.id)).to be_nil
    end

    it "returns 404 when token belongs to another user" do
      other_device = create(:device, user: other_user, push_token: "ExponentPushToken[OtherToken]")

      delete "/api/v1/devices/#{ERB::Util.url_encode(other_device.push_token)}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for nonexistent token" do
      delete "/api/v1/devices/nonexistent_token", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    context "without auth" do
      it "returns 401" do
        delete "/api/v1/devices/#{ERB::Util.url_encode(device.push_token)}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
