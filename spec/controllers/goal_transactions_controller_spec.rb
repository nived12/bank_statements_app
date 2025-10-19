# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoalTransactionsController, type: :controller do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:goal) { create(:goal, user: user, target_amount: 5000) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account, amount: 500) }

  before do
    sign_in_user user
  end

  describe "POST #create" do
    context "with valid parameters via nested route" do
      let(:valid_params) do
        {
          goal_id: goal.id,
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 500,
            notes: "Contribution to goal"
          }
        }
      end

      it "creates a new goal transaction" do
        expect {
          post :create, params: valid_params
        }.to change(GoalTransaction, :count).by(1)
      end

      it "links the transaction to the goal" do
        post :create, params: valid_params

        goal_transaction = GoalTransaction.last
        expect(goal_transaction.goal).to eq(goal)
        expect(goal_transaction.txn).to eq(transaction)
        expect(goal_transaction.amount_applied).to eq(500)
        expect(goal_transaction.notes).to eq("Contribution to goal")
      end

      it "updates goal current_amount" do
        post :create, params: valid_params
        goal.reload
        expect(goal.current_amount.to_f).to eq(500.0)
      end

      it "redirects back with success message" do
        request.env["HTTP_REFERER"] = goal_path(goal)
        post :create, params: valid_params
        expect(response).to redirect_to(goal_path(goal))
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

      it "creates a new goal transaction" do
        expect {
          post :create, params: valid_params
        }.to change(GoalTransaction, :count).by(1)
      end

      it "applies the correct amount" do
        post :create, params: valid_params

        goal_transaction = GoalTransaction.last
        expect(goal_transaction.amount_applied).to eq(300)
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          goal_id: goal.id,
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 0
          }
        }
      end

      it "does not create a goal transaction" do
        expect {
          post :create, params: invalid_params
        }.not_to change(GoalTransaction, :count)
      end

      it "redirects back with error message" do
        request.env["HTTP_REFERER"] = goal_path(goal)
        post :create, params: invalid_params
        expect(response).to redirect_to(goal_path(goal))
        expect(flash[:alert]).to be_present
      end
    end

    context "when transaction is already linked" do
      let!(:existing_link) { create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 200) }
      let(:duplicate_params) do
        {
          goal_id: goal.id,
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 100
          }
        }
      end

      it "does not create a duplicate link" do
        expect {
          post :create, params: duplicate_params
        }.not_to change(GoalTransaction, :count)
      end

      it "shows error message" do
        request.env["HTTP_REFERER"] = goal_path(goal)
        post :create, params: duplicate_params
        expect(flash[:alert]).to be_present
      end
    end

    context "with archived goal" do
      let(:archived_goal) { create(:goal, user: user, status: "archived") }
      let(:archived_params) do
        {
          goal_id: archived_goal.id,
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 500
          }
        }
      end

      it "does not create a goal transaction" do
        expect {
          post :create, params: archived_params
        }.not_to change(GoalTransaction, :count)
      end
    end

    context "with other user's goal" do
      let(:other_user_goal) { create(:goal) }
      let(:unauthorized_params) do
        {
          goal_id: other_user_goal.id,
          goal_transaction: {
            transaction_id: transaction.id,
            amount_applied: 500
          }
        }
      end

      it "raises not found error" do
        expect {
          post :create, params: unauthorized_params
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:goal_transaction) { create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 500) }

    before do
      goal.reload # Ensure current_amount reflects the linked transaction
    end

    context "via nested route" do
      it "destroys the goal transaction" do
        expect {
          delete :destroy, params: { goal_id: goal.id, id: goal_transaction.id }
        }.to change(GoalTransaction, :count).by(-1)
      end

      it "updates goal current_amount" do
        initial_amount = goal.current_amount
        delete :destroy, params: { goal_id: goal.id, id: goal_transaction.id }
        goal.reload
        expect(goal.current_amount).to eq(initial_amount - 500)
      end

      it "redirects back with success message" do
        request.env["HTTP_REFERER"] = goal_path(goal)
        delete :destroy, params: { goal_id: goal.id, id: goal_transaction.id }
        expect(response).to redirect_to(goal_path(goal))
      end
    end

    context "via flat route" do
      it "destroys the goal transaction" do
        expect {
          delete :destroy, params: { id: goal_transaction.id }
        }.to change(GoalTransaction, :count).by(-1)
      end
    end

    context "with other user's goal transaction" do
      let(:other_user_goal) { create(:goal) }
      let(:other_user_transaction) { create(:transaction, user: other_user_goal.user, bank_account: create(:bank_account, user: other_user_goal.user)) }
      let!(:other_goal_transaction) { create(:goal_transaction, goal: other_user_goal, txn: other_user_transaction, amount_applied: 100) }

      it "raises not found error" do
        expect {
          delete :destroy, params: { id: other_goal_transaction.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "unlinking reverts completed goal" do
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
      delete :destroy, params: { goal_id: completed_goal.id, id: gt2.id }
      completed_goal.reload
      expect(completed_goal.status).to eq("active")
      expect(completed_goal.current_amount.to_f).to eq(600.0)
    end
  end
end
