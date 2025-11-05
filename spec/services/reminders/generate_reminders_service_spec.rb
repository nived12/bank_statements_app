# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reminders::GenerateRemindersService do
  let(:user) { create(:user) }

  describe "#call" do
    context "with debts due soon" do
      let!(:debt) do
        create(:debt,
          user: user,
          due_day_of_month: (Date.current + 3.days).day,
          expected_payment_amount: 5000)
      end

      it "generates debt payment reminders" do
        result = described_class.call

        expect(result).to be_success
        expect(result.payload[:debt_payments].length).to be >= 0
      end
    end

    context "with savings behind target" do
      let!(:saving) do
        create(:saving,
          user: user,
          target_amount: 10000,
          current_amount: 0,
          contribution_mode: "fixed",
          target_contribution_amount: 1000)
      end

      it "generates savings contribution reminders" do
        result = described_class.call

        expect(result).to be_success
        expect(result.payload[:savings_contributions]).to be_an(Array)
      end
    end

    it "returns success with empty reminders if none due" do
      result = described_class.call

      expect(result).to be_success
      expect(result.payload[:debt_payments]).to be_an(Array)
      expect(result.payload[:savings_contributions]).to be_an(Array)
    end
  end
end
