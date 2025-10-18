# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ProjectCompletionService do
  let(:user) { create(:user) }
  let(:goal) do
    create(:goal,
           user: user,
           target_amount: 5000,
           current_amount: 2000,
           deadline: 6.months.from_now)
  end

  describe "#call" do
    it "calculates projection successfully" do
      result = described_class.call(goal, 500)

      expect(result).to be_success
      expect(result.payload).to be_a(Hash)
    end

    it "includes projected completion date" do
      result = described_class.call(goal, 500)

      expect(result.payload[:projected_completion_date]).to be_a(Date)
      expect(result.payload[:months_to_completion]).to be_a(Integer)
    end

    it "indicates if will meet deadline" do
      result = described_class.call(goal, 1000)

      expect(result.payload[:will_meet_deadline]).to be_in([true, false])
    end

    it "fails with zero or negative amount" do
      result = described_class.call(goal, 0)

      expect(result).to be_failure
    end

    it "fails for completed goal" do
      goal.update!(status: "completed")

      result = described_class.call(goal, 500)

      expect(result).to be_failure
    end
  end
end
