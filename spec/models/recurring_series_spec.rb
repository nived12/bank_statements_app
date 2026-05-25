# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecurringSeries, type: :model do
  describe "validations" do
    it "is valid with default factory" do
      expect(build(:recurring_series)).to be_valid
    end

    it "requires name, expected_amount, frequency, status, source" do
      s = build(:recurring_series, name: nil, expected_amount: nil, frequency: nil, status: nil, source: nil)
      expect(s).not_to be_valid
      expect(s.errors[:name]).to be_present
      expect(s.errors[:expected_amount]).to be_present
      expect(s.errors[:frequency]).to be_present
      expect(s.errors[:status]).to be_present
      expect(s.errors[:source]).to be_present
    end

    it "rejects invalid frequency / status / source" do
      expect(build(:recurring_series, frequency: "bogus")).not_to be_valid
      expect(build(:recurring_series, status: "bogus")).not_to be_valid
      expect(build(:recurring_series, source: "bogus")).not_to be_valid
    end

    it "requires custom_interval_days when frequency is custom" do
      expect(build(:recurring_series, frequency: "custom")).not_to be_valid
      expect(build(:recurring_series, frequency: "custom", custom_interval_days: 45)).to be_valid
    end
  end

  describe "#interval_days" do
    it "returns FREQUENCY_DAYS for known frequencies" do
      expect(build(:recurring_series, frequency: "weekly").interval_days).to eq(7)
      expect(build(:recurring_series, frequency: "monthly").interval_days).to eq(30)
      expect(build(:recurring_series, frequency: "quarterly").interval_days).to eq(91)
    end

    it "returns custom_interval_days for custom frequency" do
      expect(build(:recurring_series, frequency: "custom", custom_interval_days: 45).interval_days).to eq(45)
    end

    it "falls back to 30 when custom_interval_days is nil (bypassed validations)" do
      s = build(:recurring_series, frequency: "custom", custom_interval_days: 45)
      s.custom_interval_days = nil
      expect(s.interval_days).to eq(30)
    end
  end

  describe ".totals_for" do
    let(:user) { create(:user) }

    before do
      create(
        :recurring_series, user: user, frequency: "monthly", expected_amount: 219.0,
        transaction_type: "fixed_expense", status: "active", description_signature: "a"
      )
      create(
        :recurring_series, user: user, frequency: "weekly",  expected_amount: 50.0,
        transaction_type: "fixed_expense", status: "active", description_signature: "b"
      )
      create(
        :recurring_series, user: user, frequency: "monthly", expected_amount: 15_000.0,
        transaction_type: "income",     status: "active", description_signature: "c"
      )
      create(
        :recurring_series, user: user, frequency: "monthly", expected_amount: 100.0,
        transaction_type: "fixed_expense", status: "paused", description_signature: "d"
      )
    end

    it "sums monthly/annual via SQL, excludes non-active rows, signs income negatively" do
      totals = described_class.totals_for(user.recurring_series.active)
      # 219 (monthly) + 50 * 30/7 (weekly) - 15000 (income, monthly) = roughly -14566.71
      expect(totals[:monthly_total]).to be_within(0.5).of(-14_566.71)
      expect(totals[:annual_total]).to be_within(5.0).of(-14_566.71 * 12)
      expect(totals[:count]).to eq(3)
    end

    it "returns zeros for an empty scope" do
      totals = described_class.totals_for(user.recurring_series.where(id: 0))
      expect(totals).to eq(monthly_total: 0.0, annual_total: 0.0, count: 0)
    end
  end

  describe "#advance_due_date!" do
    let(:series) { create(:recurring_series, frequency: "monthly", next_due_date: Date.new(2026, 5, 1)) }

    it "moves next_due_date forward by interval_days" do
      series.advance_due_date!
      expect(series.reload.next_due_date).to eq(Date.new(2026, 5, 31))
    end
  end

  describe "#monthly_estimate / #annual_estimate" do
    it "computes from interval_days" do
      s = build(:recurring_series, expected_amount: 200, frequency: "weekly")
      expect(s.monthly_estimate).to be_within(0.01).of(857.14)
      expect(s.annual_estimate).to be_within(0.01).of(10428.57)
    end
  end

  describe "uniqueness on (user_id, description_signature)" do
    let(:existing) { create(:recurring_series) }

    it "rejects duplicates for the same user" do
      duplicate = build(:recurring_series, user: existing.user, description_signature: existing.description_signature)
      expect(duplicate).not_to be_valid
    end

    it "allows same signature across different users" do
      other = build(:recurring_series, description_signature: existing.description_signature)
      expect(other).to be_valid
    end
  end
end
