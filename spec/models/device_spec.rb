# frozen_string_literal: true

require "rails_helper"

RSpec.describe Device, type: :model do
  let(:user) { create(:user, :confirmed) }

  describe "validations" do
    it "is valid with push_token, platform, and user" do
      device = build(:device, user: user)
      expect(device).to be_valid
    end

    it "requires push_token" do
      device = build(:device, user: user, push_token: nil)
      expect(device).not_to be_valid
      expect(device.errors[:push_token]).not_to be_empty
    end

    it "requires platform" do
      device = build(:device, user: user, platform: nil)
      expect(device).not_to be_valid
    end

    it "rejects invalid platform" do
      device = build(:device, user: user, platform: "windows_phone")
      expect(device).not_to be_valid
      expect(device.errors[:platform]).to be_present
    end

    it "accepts ios, android, web platforms" do
      %w[ios android web].each do |platform|
        device = build(:device, user: user, platform: platform)
        expect(device).to be_valid, "Expected #{platform} to be valid"
      end
    end

    it "enforces uniqueness of push_token per user" do
      create(:device, user: user, push_token: "token123")
      duplicate = build(:device, user: user, push_token: "token123")
      expect(duplicate).not_to be_valid
    end

    it "allows same token for different users" do
      other_user = create(:user, :confirmed)
      create(:device, user: user, push_token: "shared_token")
      device = build(:device, user: other_user, push_token: "shared_token")
      expect(device).to be_valid
    end
  end

  describe "scopes" do
    it ".active returns only active devices" do
      active = create(:device, user: user, active: true)
      _inactive = create(:device, user: user, push_token: "other_token", active: false)

      expect(Device.active).to contain_exactly(active)
    end
  end
end
