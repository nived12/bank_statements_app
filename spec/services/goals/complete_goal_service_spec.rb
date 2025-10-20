# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::CompleteGoalService do
  let(:user) { create(:user) }
  let(:goal) { create(:goal, user: user, target_amount: 5000, current_amount: 5000) }

  describe "#call" do
    it "completes goal successfully when target is met" do
      result = described_class.call(goal)

      expect(result).to be_success
      expect(goal.reload.status).to eq("completed")
    end

    it "fails when target is not met" do
      goal.update!(current_amount: 3000)

      result = described_class.call(goal)

      expect(result).to be_failure
      expect(result.errors[:goal]).to be_present
    end

    it "forces completion when force flag is true" do
      goal.update!(current_amount: 3000)

      result = described_class.call(goal, force: true)

      expect(result).to be_success
      expect(goal.reload.status).to eq("completed")
    end

    it "fails when already completed" do
      goal.update!(status: "completed")

      result = described_class.call(goal)

      expect(result).to be_failure
    end
  end
end
