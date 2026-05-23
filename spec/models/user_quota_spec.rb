# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserQuota, type: :model do
  describe "associations" do
    it "belongs to a user" do
      expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    end
  end

  describe "defaults" do
    let(:user) { create(:user) }

    it "is created automatically with default counters when a user is created" do
      quota = user.quota
      expect(quota).to be_present
      expect(quota.ai_usage_count).to eq(0)
      expect(quota.ai_usage_threshold_shown).to eq(0)
      expect(quota.ai_usage_reset_at).to be_nil
      expect(quota.ai_usage_anchor_day).to be_nil
    end

    it "has dependent: :destroy on the User association" do
      expect(User.reflect_on_association(:quota).options[:dependent]).to eq(:destroy)
    end
  end
end
