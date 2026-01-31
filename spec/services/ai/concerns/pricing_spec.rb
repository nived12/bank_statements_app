# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Concerns::Pricing do
  describe ".fetch_live_exchange_rate" do
    it "fetches live USD to MXN exchange rate from exchangerate-api.com" do
      # Stub HTTParty to return a successful response
      response = double("HTTParty::Response", success?: true, dig: 17.65)
      allow(HTTParty).to receive(:get).and_return(response)

      rate = described_class.fetch_live_exchange_rate

      expect(rate).to eq(17.65)
    end

    it "handles API failures gracefully" do
      allow(HTTParty).to receive(:get).and_raise(StandardError.new("API error"))

      rate = described_class.fetch_live_exchange_rate
      expect(rate).to be_nil
    end
  end

  describe ".fallback_exchange_rate" do
    it "returns ENV variable if set" do
      allow(ENV).to receive(:fetch).with("USD_TO_MXN_RATE", "18.5").and_return("20.0")

      rate = described_class.fallback_exchange_rate
      expect(rate).to eq(20.0)
    end

    it "returns default value if ENV not set" do
      allow(ENV).to receive(:fetch).with("USD_TO_MXN_RATE", "18.5").and_return("18.5")

      rate = described_class.fallback_exchange_rate
      expect(rate).to eq(18.5)
    end
  end

  describe ".usd_to_mxn_rate" do
    it "returns a valid exchange rate" do
      # Stub HTTParty for this test
      response = double("HTTParty::Response", success?: true, dig: 17.65)
      allow(HTTParty).to receive(:get).and_return(response)
      Rails.cache.delete("exchange_rate_usd_mxn")

      rate = described_class.usd_to_mxn_rate
      expect(rate).to be > 0
    end

    it "uses Rails cache with 24 hour expiry" do
      # Stub HTTParty for this test
      response = double("HTTParty::Response", success?: true, dig: 17.65)
      allow(HTTParty).to receive(:get).and_return(response)
      Rails.cache.delete("exchange_rate_usd_mxn")

      # Verify the method uses Rails.cache.fetch with correct expiry
      expect(Rails.cache).to receive(:fetch).with("exchange_rate_usd_mxn", expires_in: 24.hours).and_call_original

      described_class.usd_to_mxn_rate
    end
  end

  describe "USD_TO_MXN_RATE constant" do
    it "is set to a valid rate" do
      expect(Ai::Concerns::Pricing::USD_TO_MXN_RATE).to be > 0
    end
  end
end
