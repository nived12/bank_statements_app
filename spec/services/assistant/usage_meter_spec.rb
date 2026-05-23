# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::UsageMeter do
  let(:user) { create(:user) }

  def make_paid!(period_start: Time.current)
    user.update_columns(trial_ends_at: nil)
    customer = create(:pay_customer, owner: user)
    sub = create(:pay_subscription, customer: customer, status: "active")
    sub.update_columns(current_period_start: period_start, current_period_end: period_start + 1.month) \
      if sub.has_attribute?(:current_period_start)
    sub
  end

  describe "#access_result" do
    context "trial user" do
      before { user.update_columns(trial_ends_at: 7.days.from_now) }

      it "returns allowed when under the trial pool" do
        expect(described_class.new(user).access_result).to eq({ allowed: true })
      end

      it "returns ai_limit_reached when ai_usage_count hits the trial cap" do
        user.quota.update_columns(ai_usage_count: SubscriptionAccess.free_tier_ai_calls)
        result = described_class.new(user).access_result

        expect(result[:allowed]).to be false
        expect(result[:reason]).to eq(:ai_limit_reached)
      end
    end

    context "non-paying, no trial" do
      before { user.update_columns(trial_ends_at: 1.day.ago) }

      it "returns subscription_required" do
        result = described_class.new(user).access_result
        expect(result[:allowed]).to be false
        expect(result[:reason]).to eq(:subscription_required)
      end
    end

    context "paid user" do
      before { make_paid! }

      it "returns allowed when under the monthly cap" do
        expect(described_class.new(user).access_result[:allowed]).to be true
      end

      it "returns assistant_limit_reached at the monthly cap" do
        meter = described_class.new(user)
        meter.access_result # initialize reset_at
        user.quota.update_columns(ai_usage_count: SubscriptionAccess.premium_monthly_ai_calls)

        result = described_class.new(user).access_result

        expect(result[:allowed]).to be false
        expect(result[:reason]).to eq(:assistant_limit_reached)
        expect(result[:message]).to be_present
      end
    end
  end

  describe "#consume!" do
    it "increments ai_usage_count for trial users" do
      user.update_columns(trial_ends_at: 7.days.from_now)
      user.quota.update_columns(ai_usage_count: 5)

      described_class.new(user).consume!

      expect(user.quota.reload.ai_usage_count).to eq(6)
    end

    it "increments ai_usage_count for paid users" do
      make_paid!
      user.quota.update_columns(ai_usage_count: 7)
      described_class.new(user).access_result # initialize anchor

      described_class.new(user).consume!

      expect(user.quota.reload.ai_usage_count).to eq(8)
    end

    it "raises QuotaExceeded when at monthly cap (paid)" do
      make_paid!
      described_class.new(user).access_result # initialize anchor
      user.quota.update_columns(ai_usage_count: SubscriptionAccess.premium_monthly_ai_calls)

      expect { described_class.new(user).consume! }.to raise_error(Assistant::QuotaExceeded)
    end

    it "raises QuotaExceeded when trial limit reached" do
      user.update_columns(trial_ends_at: 7.days.from_now)
      user.quota.update_columns(ai_usage_count: SubscriptionAccess.free_tier_ai_calls)

      expect { described_class.new(user).consume! }.to raise_error(Assistant::QuotaExceeded)
    end
  end

  describe "anchor reset behavior" do
    before { make_paid! }

    it "zeros the counter and advances reset_at by 1 month when crossed" do
      anchor = Time.zone.local(2026, 6, 19, 12, 0, 0)
      user.quota.update_columns(
        ai_usage_count: 42,
        ai_usage_reset_at: anchor,
        ai_usage_anchor_day: nil
      )

      travel_to(anchor + 1.hour) do
        described_class.new(user).advance_anchor_if_due!
      end

      user.quota.reload
      expect(user.quota.ai_usage_count).to eq(0)
      expect(user.quota.ai_usage_reset_at).to eq(anchor + 1.month)
    end

    it "loops to the next future anchor when multiple months have passed" do
      anchor = Time.zone.local(2026, 3, 10, 12, 0, 0)
      user.quota.update_columns(
        ai_usage_count: 80,
        ai_usage_reset_at: anchor,
        ai_usage_anchor_day: nil
      )

      travel_to(Time.zone.local(2026, 6, 12, 12, 0, 0)) do
        described_class.new(user).advance_anchor_if_due!
      end

      user.quota.reload
      expect(user.quota.ai_usage_count).to eq(0)
      expect(user.quota.ai_usage_reset_at).to be > Time.zone.local(2026, 6, 12, 12, 0, 0)
    end

    it "handles 31st subscription day across February without losing the anchor day" do
      anchor = Time.zone.local(2026, 1, 31, 12, 0, 0)
      user.quota.update_columns(
        ai_usage_count: 50,
        ai_usage_reset_at: anchor,
        ai_usage_anchor_day: nil
      )

      travel_to(Time.zone.local(2026, 2, 5, 12, 0, 0)) do
        described_class.new(user).advance_anchor_if_due!
      end

      feb_anchor = user.quota.reload.ai_usage_reset_at
      expect(feb_anchor.month).to eq(2)
      expect(feb_anchor.day).to be_between(28, 29).inclusive

      travel_to(Time.zone.local(2026, 3, 5, 12, 0, 0)) do
        described_class.new(user).advance_anchor_if_due!
      end

      mar_anchor = user.quota.reload.ai_usage_reset_at
      expect(mar_anchor.month).to eq(3)
      expect(mar_anchor.day).to eq(31)
    end

    it "is a no-op when reset_at is in the future" do
      future = Time.current + 10.days
      user.quota.update_columns(
        ai_usage_count: 42,
        ai_usage_reset_at: future,
        ai_usage_anchor_day: nil
      )

      described_class.new(user).advance_anchor_if_due!

      user.quota.reload
      expect(user.quota.ai_usage_count).to eq(42)
      expect(user.quota.ai_usage_reset_at).to be_within(1.second).of(future)
    end
  end

  describe "#snapshot" do
    it "exposes plan, used, limit, remaining, resets_at for paid user" do
      make_paid!
      user.quota.update_columns(ai_usage_count: 12)

      snap = described_class.new(user).snapshot

      expect(snap[:plan]).to eq("premium")
      expect(snap[:limit]).to eq(SubscriptionAccess.premium_monthly_ai_calls)
      expect(snap[:used]).to eq(12)
      expect(snap[:remaining]).to eq(SubscriptionAccess.premium_monthly_ai_calls - 12)
      expect(snap[:resets_at]).to be_present
    end

    it "exposes the shared-pool snapshot for trial users" do
      limit = SubscriptionAccess.free_tier_ai_calls
      used  = 4
      user.update_columns(trial_ends_at: 7.days.from_now)
      user.quota.update_columns(ai_usage_count: used)

      snap = described_class.new(user).snapshot

      expect(snap[:plan]).to eq("trial")
      expect(snap[:limit]).to eq(limit)
      expect(snap[:used]).to eq(used)
      expect(snap[:remaining]).to eq(limit - used)
    end
  end

  describe "threshold_crossed in snapshot" do
    context "premium user" do
      before do
        make_paid!
        described_class.new(user).access_result # initialize reset_at
      end

      it "returns 80 the first time the user crosses 80%" do
        user.quota.update_columns(
          ai_usage_count: (SubscriptionAccess.premium_monthly_ai_calls * 0.80).to_i,
          ai_usage_threshold_shown: 0
        )

        snap = described_class.new(user).snapshot

        expect(snap[:threshold_crossed]).to eq(80)
        expect(user.quota.reload.ai_usage_threshold_shown).to eq(80)
      end

      it "does not return a threshold on subsequent snapshots after 80 was already shown" do
        user.quota.update_columns(
          ai_usage_count: (SubscriptionAccess.premium_monthly_ai_calls * 0.85).to_i,
          ai_usage_threshold_shown: 80
        )

        snap = described_class.new(user).snapshot

        expect(snap[:threshold_crossed]).to be_nil
      end

      it "returns 90 when crossing 90% even if 80 was already shown" do
        user.quota.update_columns(
          ai_usage_count: (SubscriptionAccess.premium_monthly_ai_calls * 0.90).to_i,
          ai_usage_threshold_shown: 80
        )

        snap = described_class.new(user).snapshot

        expect(snap[:threshold_crossed]).to eq(90)
        expect(user.quota.reload.ai_usage_threshold_shown).to eq(90)
      end

      it "returns 95 when crossing 95% even if 90 was already shown" do
        user.quota.update_columns(
          ai_usage_count: (SubscriptionAccess.premium_monthly_ai_calls * 0.95).to_i,
          ai_usage_threshold_shown: 90
        )

        snap = described_class.new(user).snapshot

        expect(snap[:threshold_crossed]).to eq(95)
      end

      it "resets the shown threshold when the anchor advances" do
        anchor = Time.zone.local(2026, 6, 19, 12, 0, 0)
        user.quota.update_columns(
          ai_usage_count: 85,
          ai_usage_reset_at: anchor,
          ai_usage_anchor_day: nil,
          ai_usage_threshold_shown: 80
        )

        travel_to(anchor + 1.hour) do
          described_class.new(user).advance_anchor_if_due!
        end

        expect(user.quota.reload.ai_usage_threshold_shown).to eq(0)
      end
    end

    context "trial user" do
      before { user.update_columns(trial_ends_at: 7.days.from_now) }

      it "returns 80 when trial user crosses 80%" do
        threshold_count = (SubscriptionAccess.free_tier_ai_calls * 0.80).to_i
        user.quota.update_columns(ai_usage_count: threshold_count, ai_usage_threshold_shown: 0)

        snap = described_class.new(user).snapshot

        expect(snap[:threshold_crossed]).to eq(80)
      end
    end
  end
end
