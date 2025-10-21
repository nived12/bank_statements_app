# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GoalTransactions", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:goal) { create(:goal, user: user, target_amount: 5000) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account, amount: 500) }

  before do
    sign_in_user user
  end

  describe "DELETE /goals/:goal_id/transactions/:id" do
    let!(:goal_transaction) { create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 500) }

    before do
      goal.reload # Ensure current_amount reflects the linked transaction
    end

    it "destroys the goal transaction" do
      expect {
        delete goal_goal_transaction_path(goal, goal_transaction)
      }.to change(GoalTransaction, :count).by(-1)
    end

    it "updates goal current_amount" do
      initial_amount = goal.current_amount

      delete goal_goal_transaction_path(goal, goal_transaction)

      goal.reload
      expect(goal.current_amount).to eq(initial_amount - 500)
    end

    it "redirects back successfully" do
      delete goal_goal_transaction_path(goal, goal_transaction)
      expect(response).to have_http_status(:redirect)
    end

    context "with other user's goal transaction" do
      let(:other_user_goal) { create(:goal) }
      let(:other_user_transaction) { create(:transaction, user: other_user_goal.user, bank_account: create(:bank_account, user: other_user_goal.user)) }
      let!(:other_goal_transaction) { create(:goal_transaction, goal: other_user_goal, txn: other_user_transaction, amount_applied: 100) }

      it "prevents access to other user's goal transaction" do
        delete goal_goal_transaction_path(other_user_goal, other_goal_transaction)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "status reversion when unlinking" do
    let(:completed_goal) { create(:goal, user: user, target_amount: 1000, status: "active") }
    let(:txn1) { create(:transaction, user: user, bank_account: bank_account, amount: 600) }
    let(:txn2) { create(:transaction, user: user, bank_account: bank_account, amount: 500) }
    let!(:gt1) { create(:goal_transaction, goal: completed_goal, txn: txn1, amount_applied: 600) }
    let!(:gt2) { create(:goal_transaction, goal: completed_goal, txn: txn2, amount_applied: 500) }

    before do
      completed_goal.reload
      completed_goal.complete_goal!
    end

    it "reverts status to active when falling below target" do
      expect(completed_goal.status).to eq("completed")

      delete goal_goal_transaction_path(completed_goal, gt2)

      completed_goal.reload
      expect(completed_goal.status).to eq("active")
      expect(completed_goal.current_amount.to_f).to eq(600.0)
    end
  end

  describe "service integration" do
    it "uses UnlinkTransactionService for unlinking" do
      goal_transaction = create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 500)
      goal.reload

      expect {
        delete goal_goal_transaction_path(goal, goal_transaction)
      }.to change(GoalTransaction, :count).by(-1)

      # Verify UnlinkTransactionService logic worked
      goal.reload
      expect(goal.current_amount.to_f).to eq(0.0)
    end
  end
end
