# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  describe "associations" do
    it "belongs to user" do
      user = create(:user)
      expect(user.subscription).to be_present
      expect(user.subscription.user).to eq(user)
    end
  end

  describe "validations" do
    it "validates uniqueness of user_id" do
      user = create(:user)
      # User already has subscription from after_create callback
      duplicate = build(:subscription, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end

  describe "enums" do
    it "defines plan enum with string values" do
      expect(Subscription.plans).to eq({
        "free" => "free",
        "pro" => "pro",
        "enterprise" => "enterprise"
      })
    end

    it "defines status enum with string values" do
      expect(Subscription.statuses).to eq({
        "trialing" => "trialing",
        "active" => "active",
        "past_due" => "past_due",
        "cancelled" => "cancelled"
      })
    end
  end

  describe "plan scopes" do
    let!(:free_user) { create(:user) }
    let!(:pro_user) { create(:user) }
    let!(:enterprise_user) { create(:user) }

    before do
      # Update plans (users get free+trialing by default)
      pro_user.subscription.update!(plan: :pro)
      enterprise_user.subscription.update!(plan: :enterprise)
    end

    it "filters by free plan" do
      expect(Subscription.free).to include(free_user.subscription)
      expect(Subscription.free).not_to include(pro_user.subscription, enterprise_user.subscription)
    end

    it "filters by pro plan" do
      expect(Subscription.pro).to include(pro_user.subscription)
      expect(Subscription.pro).not_to include(free_user.subscription, enterprise_user.subscription)
    end

    it "filters by enterprise plan" do
      expect(Subscription.enterprise).to include(enterprise_user.subscription)
      expect(Subscription.enterprise).not_to include(free_user.subscription, pro_user.subscription)
    end
  end

  describe "status scopes" do
    let!(:trialing_user) { create(:user) }
    let!(:active_user) { create(:user) }
    let!(:past_due_user) { create(:user) }
    let!(:cancelled_user) { create(:user) }

    before do
      # Users get trialing by default, update others
      active_user.subscription.update!(status: :active)
      past_due_user.subscription.update!(status: :past_due)
      cancelled_user.subscription.update!(status: :cancelled)
    end

    it "filters by trialing status" do
      expect(Subscription.trialing).to include(trialing_user.subscription)
    end

    it "filters by active status" do
      expect(Subscription.active).to include(active_user.subscription)
    end

    it "filters by past_due status" do
      expect(Subscription.past_due).to include(past_due_user.subscription)
    end

    it "filters by cancelled status" do
      expect(Subscription.cancelled).to include(cancelled_user.subscription)
    end
  end
end
