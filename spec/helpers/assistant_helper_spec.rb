# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssistantHelper, type: :helper do
  describe "#recency_bucket" do
    let(:now) { Time.zone.local(2026, 5, 19, 15, 0, 0) }

    around do |example|
      travel_to(now) { example.run }
    end

    it "returns :today for a time earlier today" do
      expect(helper.recency_bucket(now - 6.hours)).to eq(:today)
    end

    it "returns :today for the very start of today" do
      expect(helper.recency_bucket(now.beginning_of_day + 1.minute)).to eq(:today)
    end

    it "returns :yesterday for a time within the prior calendar day" do
      expect(helper.recency_bucket(now - 1.day)).to eq(:yesterday)
    end

    it "returns :this_week for a time 3 days ago" do
      expect(helper.recency_bucket(now - 3.days)).to eq(:this_week)
    end

    it "returns :this_week for a time 6 days ago" do
      expect(helper.recency_bucket(now - 6.days)).to eq(:this_week)
    end

    it "returns :earlier for a time 7+ days ago" do
      expect(helper.recency_bucket(now - 7.days)).to eq(:earlier)
    end

    it "returns :earlier for nil" do
      expect(helper.recency_bucket(nil)).to eq(:earlier)
    end
  end
end
