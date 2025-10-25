# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::CreateService do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  describe "#call" do
    context "with valid savings goal parameters" do
      let(:valid_params) do
        {
          name: "Vacation Fund",
          goal_type: "savings_goal",
          start_date: Date.today,
          deadline: 6.months.from_now,
          icon: "🏖️",
          color: "#FF5733"
        }
      end

      it "creates a goal successfully" do
        result = described_class.call(user, valid_params)

        expect(result).to be_success
        expect(result.payload).to be_a(Goal)
        expect(result.payload.user).to eq(user)
        expect(result.payload.name).to eq("Vacation Fund")
        expect(result.payload.goal_type).to eq("savings_goal")
        expect(result.payload.status).to eq("active")
      end

      it "sets default values" do
        result = described_class.call(user, valid_params)

        expect(result.payload.status).to eq("active")
      end
    end

    context "with valid debt payoff parameters" do
      let(:debt_params) do
        {
          name: "Pay Off Credit Card",
          goal_type: "debt_payoff",
          debt_strategy: "avalanche",
          start_date: Date.today,
          deadline: 1.year.from_now
        }
      end

      it "creates a debt payoff goal successfully" do
        result = described_class.call(user, debt_params)

        expect(result).to be_success
        expect(result.payload.goal_type).to eq("debt_payoff")
        expect(result.payload.debt_strategy).to eq("avalanche")
      end
    end

    context "with missing required fields" do
      it "fails when name is missing" do
        params = {
          goal_type: "savings_goal",
          target_amount: 5000,
          start_date: Date.today,
          deadline: 6.months.from_now
        }

        result = described_class.call(user, params)

        expect(result).to be_failure
        expect(result.errors).not_to be_empty
      end

      it "fails when deadline is missing" do
        params = {
          name: "Test Goal",
          goal_type: "savings_goal",
          target_amount: 5000,
          start_date: Date.today
        }

        result = described_class.call(user, params)

        expect(result).to be_failure
      end
    end

    context "with invalid deadline" do
      it "fails when deadline is before start_date" do
        params = {
          name: "Invalid Goal",
          goal_type: "savings_goal",
          target_amount: 5000,
          start_date: Date.today,
          deadline: 1.day.ago
        }

        result = described_class.call(user, params)

        expect(result).to be_failure
        expect(result.errors[:deadline]).to be_present
      end
    end

    context "debt payoff specific validations" do
      it "fails when debt_strategy is missing for debt payoff goals" do
        params = {
          name: "Pay Off Card",
          goal_type: "debt_payoff",
          start_date: Date.today,
          deadline: 1.year.from_now
        }

        result = described_class.call(user, params)

        expect(result).to be_failure
        expect(result.errors[:debt_strategy]).to be_present
      end
    end
  end
end
