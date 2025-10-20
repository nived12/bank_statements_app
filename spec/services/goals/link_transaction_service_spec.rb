# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::LinkTransactionService do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:goal) { create(:goal, user: user, target_amount: 5000) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account, amount: 500) }

  # Create a pre-existing transaction linked to the goal to set initial current_amount
  let!(:existing_transaction) do
    existing = create(:transaction, user: user, bank_account: bank_account, amount: 1000)
    create(:goal_transaction, goal: goal, txn: existing, amount_applied: 1000)
    existing
  end

  describe "#call" do
    context "with valid parameters" do
      it "links transaction to goal successfully" do
        result = described_class.call(goal, transaction, 500)

        expect(result).to be_success
        expect(result.payload).to be_a(GoalTransaction)
        expect(result.payload.goal).to eq(goal)
        expect(result.payload.txn).to eq(transaction)
        expect(result.payload.amount_applied).to eq(500)
      end

      it "updates goal current_amount" do
        described_class.call(goal, transaction, 500)

        goal.reload
        expect(goal.current_amount.to_f).to eq(1500.0)
      end

      it "allows partial amount application" do
        result = described_class.call(goal, transaction, 250)

        expect(result).to be_success
        expect(result.payload.amount_applied.to_f).to eq(250.0)
        goal.reload
        expect(goal.current_amount.to_f).to eq(1250.0)
      end

      it "saves notes when provided" do
        result = described_class.call(goal, transaction, 500, notes: "Vacation savings")

        expect(result).to be_success
        expect(result.payload.notes).to eq("Vacation savings")
      end
    end

    context "when goal reaches target" do
      it "auto-completes savings goal" do
        # Create a goal with transactions totaling 4600
        completion_goal = create(:goal, user: user, target_amount: 5000)
        existing_txn = create(:transaction, user: user, bank_account: bank_account, amount: 4600)
        create(:goal_transaction, goal: completion_goal, txn: existing_txn, amount_applied: 4600)

        # Adding 500 should complete it (4600 + 500 = 5100 >= 5000)
        new_txn = create(:transaction, user: user, bank_account: bank_account, amount: 500)
        result = described_class.call(completion_goal, new_txn, 500)

        expect(result).to be_success
        completion_goal.reload
        expect(completion_goal.status).to eq("completed")
      end

      it "auto-completes debt payoff goal" do
        # Create debt goal with 9600 already paid (400 remaining to target of 0)
        debt_goal = create(:goal,
                          :debt_payoff,
                          user: user,
                          starting_debt_amount: 10000,
                          target_amount: 0)
        existing_payment = create(:transaction, user: user, bank_account: bank_account, amount: 9600)
        create(:goal_transaction, goal: debt_goal, txn: existing_payment, amount_applied: 9600)

        # Adding 500 should complete it (remaining debt: 10000 - 9600 - 500 = -100, which is below target of 0)
        new_payment = create(:transaction, user: user, bank_account: bank_account, amount: 500)
        result = described_class.call(debt_goal, new_payment, 500)

        expect(result).to be_success
        debt_goal.reload
        expect(debt_goal.status).to eq("completed")
      end
    end

    context "with invalid parameters" do
      it "fails when amount is zero" do
        result = described_class.call(goal, transaction, 0)

        expect(result).to be_failure
        expect(result.errors[:amount_applied]).to be_present
      end

      it "fails when amount is negative" do
        result = described_class.call(goal, transaction, -100)

        expect(result).to be_failure
      end

      it "fails when transaction is already linked" do
        GoalTransaction.create!(goal: goal, txn: transaction, amount_applied: 100)

        result = described_class.call(goal, transaction, 200)

        expect(result).to be_failure
        expect(result.errors[:base]).to be_present
      end

      it "fails when goal is archived" do
        goal.update!(status: "archived")

        result = described_class.call(goal, transaction, 500)

        expect(result).to be_failure
        expect(result.errors[:goal]).to be_present
      end
    end

    context "multiple goals per transaction" do
      let(:goal2) { create(:goal, user: user, name: "Emergency Fund") }

      it "allows same transaction to link to multiple goals" do
        # Use a new transaction not yet linked
        multi_txn = create(:transaction, user: user, bank_account: bank_account, amount: 500)

        result1 = described_class.call(goal, multi_txn, 300)
        result2 = described_class.call(goal2, multi_txn, 200)

        expect(result1).to be_success
        expect(result2).to be_success

        goal.reload
        goal2.reload
        # goal already has 1000 from existing_transaction, plus 300 from multi_txn = 1300
        expect(goal.current_amount.to_f).to eq(1300.0)
        expect(goal2.current_amount.to_f).to eq(200.0)
      end
    end
  end
end
