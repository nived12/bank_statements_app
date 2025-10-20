# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::CalculateProgressService do
  let(:user) { create(:user) }
  let(:goal) do
    create(:goal,
           user: user,
           target_amount: 5000,
           current_amount: 2000,
           start_date: 6.months.ago,
           deadline: 6.months.from_now)
  end

  describe "#call" do
    it "returns success with metrics" do
      result = described_class.call(goal)

      expect(result).to be_success
      expect(result.payload).to be_a(Hash)
    end

    it "includes all progress metrics" do
      result = described_class.call(goal)
      metrics = result.payload

      expect(metrics[:progress_percentage]).to be_present
      expect(metrics[:current_amount]).to eq(2000.0)
      expect(metrics[:target_amount]).to eq(5000.0)
      expect(metrics[:amount_remaining]).to eq(3000.0)
    end

    it "includes time metrics" do
      result = described_class.call(goal)
      metrics = result.payload

      expect(metrics[:days_remaining]).to be_a(Integer)
      expect(metrics[:months_remaining]).to be_a(Integer)
      expect(metrics[:days_since_start]).to be_a(Integer)
    end

    it "includes contribution metrics" do
      result = described_class.call(goal)
      metrics = result.payload

      expect(metrics[:monthly_contribution_needed]).to be_a(Float)
      expect(metrics[:actual_monthly_contribution]).to be_a(Float)
    end

    it "includes status indicators" do
      result = described_class.call(goal)
      metrics = result.payload

      expect(metrics[:on_track]).to be_in([true, false])
      expect(metrics[:behind_schedule]).to be_in([true, false])
      expect(metrics[:past_deadline]).to be_in([true, false])
    end

    context "with debt payoff goal" do
      let(:debt_goal) do
        create(:goal,
               :debt_payoff,
               user: user,
               starting_debt_amount: 10000,
               current_amount: 6000)
      end

      it "includes debt-specific metrics" do
        result = described_class.call(debt_goal)
        metrics = result.payload

        expect(metrics[:starting_debt_amount]).to eq(10000.0)
        expect(metrics[:current_debt_remaining]).to eq(4000.0)
        expect(metrics[:debt_strategy]).to be_present
      end
    end
  end
end
