require "rails_helper"

RSpec.describe PaySubscriptionInterval, type: :model do
  describe "#billing_interval" do
    it "reads the interval Stripe recorded on an annual subscription" do
      sub = build(:pay_subscription, :stripe_annual)

      expect(sub.billing_interval).to eq(:year)
      expect(sub).to be_annual
    end

    it "reads the interval Stripe recorded on a monthly subscription" do
      sub = build(:pay_subscription, :stripe_monthly)

      expect(sub.billing_interval).to eq(:month)
      expect(sub).not_to be_annual
    end

    it "survives a price change that leaves processor_plan pointing at a retired price" do
      # The whole reason this concern exists. Stripe Prices are immutable, so a price
      # change repoints the env var and every existing subscription's processor_plan
      # becomes a stale ID. The old ID-comparison reported these as monthly.
      sub = build(:pay_subscription, :stripe_annual, processor_plan: "price_retired_last_year")

      expect(sub.billing_interval).to eq(:year)
    end

    context "when Pay never stored the full Stripe object" do
      it "infers annual from a year-long billing period" do
        sub = build(:pay_subscription, :stripe_annual, object: nil)

        expect(sub.billing_interval).to eq(:year)
      end

      it "infers monthly from a month-long billing period" do
        sub = build(:pay_subscription, :stripe_monthly, object: nil)

        expect(sub.billing_interval).to eq(:month)
      end

      it "treats a 28-day February period as monthly" do
        sub = build(
          :pay_subscription, :stripe_monthly, object: nil,
          current_period_start: Time.utc(2027, 2, 1), current_period_end: Time.utc(2027, 3, 1)
        )

        expect(sub.billing_interval).to eq(:month)
      end

      it "treats a leap-year period as annual" do
        sub = build(
          :pay_subscription, :stripe_annual, object: nil,
          current_period_start: Time.utc(2028, 1, 1), current_period_end: Time.utc(2029, 1, 1)
        )

        expect(sub.billing_interval).to eq(:year)
      end
    end

    it "is nil for a manually granted subscription with no Stripe price" do
      # Comp accounts (test@vitt.io, dev@vitt.io in production) carry the bare plan
      # name and no Stripe data, so there is no interval to report. Claiming "monthly"
      # here would be inventing a billing cycle that does not exist.
      sub = build(:pay_subscription)

      expect(sub.processor_plan).to eq("premium")
      expect(sub.billing_interval).to be_nil
      expect(sub).not_to be_annual
    end

    it "ignores a malformed interval rather than passing it through" do
      sub = build(
        :pay_subscription, :stripe_annual,
        object: { "items" => { "data" => [ { "price" => { "recurring" => { "interval" => "fortnight" } } } ] } },
        current_period_start: nil, current_period_end: nil
      )

      expect(sub.billing_interval).to be_nil
    end
  end

  # Stripe prices are all MXN today, but App Store subscriptions are billed in the
  # customer's own currency, so the view can no longer hardcode a symbol.
  describe "#billing_currency" do
    it "reads the currency Stripe recorded, normalised to upper case" do
      expect(build(:pay_subscription, :stripe_annual).billing_currency).to eq("MXN")
    end

    it "is nil for a manually granted subscription with no Stripe price" do
      expect(build(:pay_subscription).billing_currency).to be_nil
    end
  end
end
