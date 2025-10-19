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

  describe "POST /goals/:goal_id/transactions" do
    context "with valid parameters via nested route" do
      let(:valid_params) do
        {
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 500,
            notes: "Contribution to goal"
          }
        }
      end

      it "creates a new goal transaction" do
        expect {
          post goal_goal_transactions_path(goal), params: valid_params
        }.to change(GoalTransaction, :count).by(1)
      end

      it "links transaction to goal with correct attributes" do
        post goal_goal_transactions_path(goal), params: valid_params

        goal_transaction = GoalTransaction.last
        expect(goal_transaction.goal).to eq(goal)
        expect(goal_transaction.txn).to eq(transaction)
        expect(goal_transaction.amount_applied).to eq(500)
        expect(goal_transaction.notes).to eq("Contribution to goal")
      end

      it "updates goal current_amount" do
        expect {
          post goal_goal_transactions_path(goal), params: valid_params
          goal.reload
        }.to change { goal.current_amount.to_f }.from(0.0).to(500.0)
      end

      it "redirects back successfully" do
        post goal_goal_transactions_path(goal), params: valid_params
        expect(response).to have_http_status(:redirect)
      end
    end

    context "with valid parameters via flat route" do
      let(:valid_params) do
        {
          goal_transaction: {
            goal_id: goal.id,
            transaction_id: transaction.id,
            amount_applied: 300
          }
        }
      end

      it "creates goal transaction" do
        expect {
          post goal_transactions_path, params: valid_params
        }.to change(GoalTransaction, :count).by(1)
      end

      it "applies correct amount" do
        post goal_transactions_path, params: valid_params

        goal_transaction = GoalTransaction.last
        expect(goal_transaction.amount_applied).to eq(300)
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 0
          }
        }
      end

      it "does not create goal transaction" do
        expect {
          post goal_goal_transactions_path(goal), params: invalid_params
        }.not_to change(GoalTransaction, :count)
      end

      it "redirects back with error" do
        post goal_goal_transactions_path(goal), params: invalid_params
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when transaction is already linked" do
      let!(:existing_link) { create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 200) }
      let(:duplicate_params) do
        {
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 100
          }
        }
      end

      it "does not create duplicate link" do
        expect {
          post goal_goal_transactions_path(goal), params: duplicate_params
        }.not_to change(GoalTransaction, :count)
      end
    end

    context "with archived goal" do
      let(:archived_goal) { create(:goal, user: user, status: "archived") }
      let(:archived_params) do
        {
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 500
          }
        }
      end

      it "does not create goal transaction" do
        expect {
          post goal_goal_transactions_path(archived_goal), params: archived_params
        }.not_to change(GoalTransaction, :count)
      end
    end

    context "with other user's goal" do
      let(:other_user_goal) { create(:goal) }
      let(:unauthorized_params) do
        {
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 500
          }
        }
      end

      it "prevents access to other user's goal" do
        post goal_goal_transactions_path(other_user_goal), params: unauthorized_params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "auto-completion when target reached" do
      let(:almost_complete_goal) { create(:goal, user: user, target_amount: 1000, current_amount: 0, status: "active") }
      let(:completing_transaction) { create(:transaction, user: user, bank_account: bank_account, amount: 1000) }
      let(:completing_params) do
        {
          goal_transaction: {
            transaction_id: completing_transaction.id,
            amount_applied: 1000
          }
        }
      end

      it "auto-completes goal when target is reached" do
        post goal_goal_transactions_path(almost_complete_goal), params: completing_params

        almost_complete_goal.reload
        expect(almost_complete_goal.status).to eq("completed")
        expect(almost_complete_goal.current_amount.to_f).to eq(1000.0)
      end
    end
  end

  describe "DELETE /goals/:goal_id/transactions/:id" do
    let!(:goal_transaction) { create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 500) }

    before do
      goal.reload # Ensure current_amount reflects the linked transaction
    end

    context "via nested route" do
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
    end

    context "via flat route" do
      it "destroys the goal transaction" do
        expect {
          delete goal_transaction_path(goal_transaction)
        }.to change(GoalTransaction, :count).by(-1)
      end
    end

    context "with other user's goal transaction" do
      let(:other_user_goal) { create(:goal) }
      let(:other_user_transaction) { create(:transaction, user: other_user_goal.user, bank_account: create(:bank_account, user: other_user_goal.user)) }
      let!(:other_goal_transaction) { create(:goal_transaction, goal: other_user_goal, txn: other_user_transaction, amount_applied: 100) }

      it "prevents access to other user's goal transaction" do
        delete goal_transaction_path(other_goal_transaction)
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
    it "uses LinkTransactionService for linking" do
      params = {
        goal_transaction: {
          transaction_id: transaction.id,
          amount_applied: 500
        }
      }

      expect {
        post goal_goal_transactions_path(goal), params: params
      }.to change(GoalTransaction, :count).by(1)

      # Verify LinkTransactionService logic worked
      goal.reload
      expect(goal.current_amount.to_f).to eq(500.0)
    end

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

  describe "multiple goals per transaction" do
    let(:goal2) { create(:goal, user: user, name: "Emergency Fund", target_amount: 3000) }
    let(:multi_txn) { create(:transaction, user: user, bank_account: bank_account, amount: 500) }

    it "allows linking same transaction to multiple goals" do
      # Link to first goal
      post goal_goal_transactions_path(goal), params: {
        goal_transaction: {
          transaction_id: multi_txn.id,
          amount_applied: 300
        }
      }

      # Link to second goal
      post goal_goal_transactions_path(goal2), params: {
        goal_transaction: {
          transaction_id: multi_txn.id,
          amount_applied: 200
        }
      }

      goal.reload
      goal2.reload

      expect(goal.current_amount.to_f).to eq(300.0)
      expect(goal2.current_amount.to_f).to eq(200.0)
      expect(multi_txn.goal_transactions.count).to eq(2)
    end
  end
end
