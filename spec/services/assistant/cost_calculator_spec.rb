# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::CostCalculator do
  describe ".call" do
    it "computes gemini-3.1-flash-lite at $0.25 / $1.50 per 1M" do
      cost = described_class.call(
        provider: "gemini", model: "gemini-3.1-flash-lite",
        prompt_tokens: 1_000_000, completion_tokens: 0
      )
      expect(cost).to eq(0.25)
    end

    it "computes gemini-3-flash-preview at $0.50 / $3.00 per 1M" do
      cost = described_class.call(
        provider: "gemini", model: "gemini-3-flash-preview",
        prompt_tokens: 0, completion_tokens: 1_000_000
      )
      expect(cost).to eq(3.00)
    end

    it "computes gemini-3.5-flash at $1.50 / $9.00 per 1M" do
      cost = described_class.call(
        provider: "gemini", model: "gemini-3.5-flash",
        prompt_tokens: 1_000_000, completion_tokens: 1_000_000
      )
      expect(cost).to eq(10.50)
    end

    it "falls back to default rate ($0.25 / $1.50) for unknown gemini models" do
      cost = described_class.call(
        provider: "gemini", model: "gemini-future-model",
        prompt_tokens: 1_000_000, completion_tokens: 0
      )
      expect(cost).to eq(0.25)
    end

    it "computes a small realistic chat turn correctly" do
      cost = described_class.call(
        provider: "gemini", model: "gemini-3.1-flash-lite",
        prompt_tokens: 2_700, completion_tokens: 150
      )
      # (2700 * 0.25 + 150 * 1.50) / 1M = (675 + 225) / 1M = 0.000900
      expect(cost).to eq(0.000900)
    end
  end
end
