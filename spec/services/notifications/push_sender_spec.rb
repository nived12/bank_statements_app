# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe Notifications::PushSender, type: :service do
  let(:user) { create(:user) }

  # Deliberately a literal, not the constant. Stubbing EXPO_PUSH_URL means
  # WebMock matches whatever the code says, so the suite stayed green for months
  # against an endpoint that 404s in production and no push was ever delivered.
  # Every stub below uses this literal: a wrong constant now leaves the request
  # unstubbed and WebMock fails the example.
  expo_endpoint = "https://exp.host/--/api/v2/push/send"

  it "points at Expo's real push endpoint" do
    expect(described_class::EXPO_PUSH_URL).to eq(expo_endpoint)
  end

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
        stub_request(:post, expo_endpoint)
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
        expect(a_request(:post, expo_endpoint)).to have_been_made
      end

      it "deactivates tokens that return DeviceNotRegistered" do
        stub_request(:post, expo_endpoint)
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

      # sent used to be the number of tokens *attempted*, so a total failure
      # still reported success. That is what made the 404 invisible.
      it "counts accepted tickets, not tokens attempted" do
        stub_request(:post, expo_endpoint).to_return(
          status: 200,
          body: JSON.generate(
            data: [
              { status: "error", message: "Invalid token", details: { error: "DeviceNotRegistered" } },
              { status: "ok", id: "def" }
            ]
          ),
          headers: { "Content-Type" => "application/json" }
        )

        result = Notifications::PushSender.call(user: user, title: "Test", body: "Body")

        expect(result.payload[:sent]).to eq(1)
      end

      it "reports a non-success response instead of silently counting it as sent" do
        stub_request(:post, expo_endpoint).to_return(status: 404, body: "Not Found")
        allow(Rails.logger).to receive(:error)

        result = Notifications::PushSender.call(user: user, title: "Test", body: "Body")

        expect(result.payload[:sent]).to eq(0)
        expect(Rails.logger).to have_received(:error).with(/404/)
        expect(ios_device.reload.active).to be true # a bad response is not the token's fault
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
        expect(a_request(:post, expo_endpoint)).not_to have_been_made
      end
    end
  end
end
