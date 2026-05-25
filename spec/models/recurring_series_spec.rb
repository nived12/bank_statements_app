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
