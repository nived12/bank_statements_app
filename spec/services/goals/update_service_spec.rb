# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::UpdateService do
  let(:user) { create(:user) }
  let(:goal) { create(:goal, user: user) }

  describe "#call" do
    it "updates goal successfully" do
      result = described_class.call(goal, { name: "Updated Name" })

      expect(result).to be_success
      expect(goal.reload.name).to eq("Updated Name")
    end

    it "auto-completes goal when target is reached" do
      goal.update!(current_amount: 4900, target_amount: 5000)

      result = described_class.call(goal, { current_amount: 5000 })

      expect(result).to be_success
      expect(goal.reload.status).to eq("completed")
    end

    it "fails when deadline is before start_date" do
      result = described_class.call(goal, { deadline: goal.start_date - 1.day })

      expect(result).to be_failure
    end
  end
end
