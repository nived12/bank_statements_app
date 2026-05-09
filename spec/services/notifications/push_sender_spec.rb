# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe Notifications::PushSender, type: :service do
  let(:user) { create(:user) }

  describe ".call" do
    context "when user has no active devices" do
      it "returns success with sent: 0" do
        result = Notifications::PushSender.call(user: user, title: "Test", body: "Hello")

        expect(result.success?).to be true
        expect(result.payload[:sent]).to eq(0)
      end
    end

    context "when user has active Expo push devices" do
      let!(:ios_device) { create(:device, user: user, push_token: "ExponentPushToken[ios123]", platform: "ios") }
      let!(:android_device) do
        create(:device, user: user, push_token: "ExponentPushToken[android456]", platform: "android")
      end

      before do
        # Stub Net::HTTP to avoid real network calls
        stub_request(:post, Notifications::PushSender::EXPO_PUSH_URL)
          .to_return(
            status: 200,
            body: JSON.generate(
              {
                            data: [
                              { status: "ok", id: "abc" },
                              { status: "ok", id: "def" }
                            ]
                          }
            ),
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "sends push to Expo API and returns success" do
        result = Notifications::PushSender.call(
          user: user,
          title: "Extracto listo",
          body: "Tu extracto de BBVA está listo",
          data: { screen: "/(app)/transactions/" }
        )

        expect(result.success?).to be true
        expect(result.payload[:sent]).to eq(2)
        expect(a_request(:post, Notifications::PushSender::EXPO_PUSH_URL)).to have_been_made
      end

      it "deactivates tokens that return DeviceNotRegistered" do
        stub_request(:post, Notifications::PushSender::EXPO_PUSH_URL)
          .to_return(
            status: 200,
            body: JSON.generate(
              {
                            data: [
                              { status: "error", message: "Invalid token", details: { error: "DeviceNotRegistered" } },
                              { status: "ok", id: "def" }
                            ]
                          }
            ),
            headers: { "Content-Type" => "application/json" }
          )

        Notifications::PushSender.call(user: user, title: "Test", body: "Body")

        expect(ios_device.reload.active).to be false
        expect(android_device.reload.active).to be true
      end
    end

    context "when user has inactive devices" do
      let!(:inactive_device) do
        create(:device, user: user, push_token: "ExponentPushToken[inactive]", platform: "ios", active: false)
      end

      it "does not send to inactive devices" do
        result = Notifications::PushSender.call(user: user, title: "Test", body: "Body")

        expect(result.success?).to be true
        expect(result.payload[:sent]).to eq(0)
        expect(a_request(:post, Notifications::PushSender::EXPO_PUSH_URL)).not_to have_been_made
      end
    end
  end
end
