# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplePremiumSubscription, type: :model do
  describe "#active?" do
    it "is true while the entitlement has not expired" do
      expect(build(:apple_premium_subscription, expires_at: 1.day.from_now)).to be_active
    end

    it "is false once it has expired" do
      expect(build(:apple_premium_subscription, :expired)).not_to be_active
    end

    # Apple's expiry is the exact instant access ends, so the boundary is not
    # a rounding detail — a user at it has already lapsed.
    it "is false exactly at the expiry instant" do
      freeze_time do
        expect(build(:apple_premium_subscription, expires_at: Time.current)).not_to be_active
      end
    end
  end

  describe "validations" do
    it "allows only one row per user" do
      user = create(:user)
      create(:apple_premium_subscription, user: user)

      second = build(:apple_premium_subscription, user: user)
      expect(second).not_to be_valid
      expect(second.errors[:user_id]).to be_present
    end

    it "requires an expiry" do
      expect(build(:apple_premium_subscription, expires_at: nil)).not_to be_valid
    end
  end
end
