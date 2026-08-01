# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe Notifications::ReceiptJob, type: :job do
  # Literal, not the constant — see push_sender_spec for why stubbing the
  # constant the code reads is how a 404 endpoint survived for months.
  RECEIPTS_ENDPOINT = "https://exp.host/--/api/v2/push/getReceipts"

  let(:user) { create(:user) }
  let!(:dead_device) { create(:device, user: user, push_token: "ExponentPushToken[dead]", platform: "android") }
  let!(:live_device) { create(:device, user: user, push_token: "ExponentPushToken[live]", platform: "ios") }
  let(:ticket_map) { { "ticket-dead" => dead_device.push_token, "ticket-live" => live_device.push_token } }

  # Takes the receipts hash itself; wraps it in Expo's { data: ... } envelope.
  def stub_receipts(receipts)
    stub_request(:post, RECEIPTS_ENDPOINT).to_return(
      status: 200, body: JSON.generate(data: receipts), headers: { "Content-Type" => "application/json" }
    )
  end

  def stub_receipts_failure(status)
    stub_request(:post, RECEIPTS_ENDPOINT).to_return(status: status, body: "boom")
  end

  def dead_token_receipt
    { "status" => "error", "details" => { "error" => "DeviceNotRegistered" } }
  end

  it "points at Expo's real receipts endpoint" do
    expect(described_class::EXPO_RECEIPTS_URL).to eq(RECEIPTS_ENDPOINT)
  end

  it "deactivates only the device whose receipt says DeviceNotRegistered" do
    stub_receipts("ticket-dead" => dead_token_receipt, "ticket-live" => { "status" => "ok" })

    described_class.perform_now(user.id, ticket_map)

    expect(dead_device.reload.active).to be false
    expect(live_device.reload.active).to be true
  end

  it "asks for the ticket ids it was given" do
    stub_receipts({})

    described_class.perform_now(user.id, ticket_map)

    expect(
      a_request(:post, RECEIPTS_ENDPOINT).with { |req| JSON.parse(req.body)["ids"].sort == ticket_map.keys.sort }
    ).to have_been_made
  end

  # The point of receipts is visibility: a push Expo accepts and APNs drops is
  # otherwise completely silent.
  it "reports a delivery error that is not a dead token, without deactivating" do
    stub_receipts(
      "ticket-dead" => { "status" => "error", "message" => "too big", "details" => { "error" => "MessageTooBig" } }
    )
    allow(Rails.logger).to receive(:error)

    described_class.perform_now(user.id, ticket_map)

    expect(Rails.logger).to have_received(:error).with(/MessageTooBig/)
    expect(dead_device.reload.active).to be true
  end

  it "reports a non-success response and deactivates nothing" do
    stub_receipts_failure(502)
    allow(Rails.logger).to receive(:error)

    described_class.perform_now(user.id, ticket_map)

    expect(Rails.logger).to have_received(:error).with(/502/)
    expect(dead_device.reload.active).to be true
  end

  # The token belongs ONLY to another user, so this cannot pass by row order:
  # an unscoped Device.find_by(push_token:) finds it and deactivates the wrong
  # person's device. push_token is unique per user, not globally — two accounts
  # on one handset share a token.
  it "never touches another user's device" do
    foreign = create(:device, user: create(:user), push_token: "ExponentPushToken[foreign]", platform: "android")
    stub_receipts("t1" => dead_token_receipt)

    described_class.perform_now(user.id, { "t1" => foreign.push_token })

    expect(foreign.reload.active).to be true
  end

  it "does nothing when there are no tickets" do
    described_class.perform_now(user.id, {})

    expect(a_request(:post, RECEIPTS_ENDPOINT)).not_to have_been_made
  end

  it "does not raise when the user has been deleted" do
    expect { described_class.perform_now(-1, ticket_map) }.not_to raise_error
  end
end
