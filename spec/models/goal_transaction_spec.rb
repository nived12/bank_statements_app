require "rails_helper"

RSpec.describe GoalTransaction, type: :model do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:goal) { create(:goal, user: user) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account) }
  let(:goal_transaction) { create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 500) }

  describe "associations" do
    it "belongs to a goal" do
      expect(goal_transaction.goal).to eq(goal)
    end

    it "belongs to a transaction via txn association" do
      expect(goal_transaction.txn).to eq(transaction)
    end
  end

  describe "validations" do
    it "is valid with all required attributes" do
      expect(goal_transaction).to be_valid
    end

    it "requires a goal_id" do
      goal_transaction.goal_id = nil
      expect(goal_transaction).not_to be_valid
      expect(goal_transaction.errors[:goal_id]).to be_present
    end

    it "requires a transaction_id" do
      goal_transaction.transaction_id = nil
      expect(goal_transaction).not_to be_valid
      expect(goal_transaction.errors[:transaction_id]).to be_present
    end

    it "requires an amount_applied" do
      goal_transaction.amount_applied = nil
      expect(goal_transaction).not_to be_valid
      expect(goal_transaction.errors[:amount_applied]).to be_present
    end

    it "requires amount_applied to be greater than 0" do
      goal_transaction.amount_applied = 0
      expect(goal_transaction).not_to be_valid
    end

    it "requires amount_applied to be positive" do
      goal_transaction.amount_applied = -100
      expect(goal_transaction).not_to be_valid
    end

    it "prevents duplicate goal-transaction pairs" do
      goal_transaction.save!
      duplicate = build(:goal_transaction, goal: goal, txn: transaction, amount_applied: 200)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:transaction_id]).to include("is already linked to this goal")
    end

    it "allows the same transaction to be linked to different goals" do
      goal2 = create(:goal, user: user, name: "Another Goal")
      goal_transaction.save!
      another_link = build(:goal_transaction, goal: goal2, txn: transaction, amount_applied: 300)
      expect(another_link).to be_valid
    end

    it "allows the same goal to be linked to different transactions" do
      transaction2 = create(:transaction, user: user, bank_account: bank_account)
      goal_transaction.save!
      another_link = build(:goal_transaction, goal: goal, txn: transaction2, amount_applied: 300)
      expect(another_link).to be_valid
    end
  end

  describe "callbacks" do
    describe "after_save" do
      it "updates goal current_amount when created" do
        initial_amount = goal.current_amount
        create(:goal_transaction, goal: goal, txn: transaction, amount_applied: 500)
        goal.reload
        expect(goal.current_amount).to eq(initial_amount + 500)
      end

      it "updates goal current_amount when updated" do
        goal_transaction.save!
        goal.reload
        initial_amount = goal.current_amount

        goal_transaction.update(amount_applied: 700)
        goal.reload
        expect(goal.current_amount).to eq(initial_amount - 500 + 700)
      end
    end

    describe "after_destroy" do
      it "updates goal current_amount when destroyed" do
        goal_transaction.save!
        goal.reload
        initial_amount = goal.current_amount

        goal_transaction.destroy
        goal.reload
        expect(goal.current_amount).to eq(initial_amount - 500)
      end
    end
  end

  describe "multiple transactions for one goal" do
    let(:transaction1) { create(:transaction, user: user, bank_account: bank_account) }
    let(:transaction2) { create(:transaction, user: user, bank_account: bank_account) }
    let(:transaction3) { create(:transaction, user: user, bank_account: bank_account) }

    it "correctly calculates goal current_amount with multiple transactions" do
      create(:goal_transaction, goal: goal, txn: transaction1, amount_applied: 500)
      create(:goal_transaction, goal: goal, txn: transaction2, amount_applied: 300)
      create(:goal_transaction, goal: goal, txn: transaction3, amount_applied: 200)

      goal.reload
      expect(goal.current_amount).to eq(1000)
    end
  end

  describe "transaction linked to multiple goals" do
    let(:goal1) { create(:goal, user: user, name: "Goal 1") }
    let(:goal2) { create(:goal, user: user, name: "Goal 2") }

    it "allows one transaction to contribute to multiple goals" do
      create(:goal_transaction, goal: goal1, txn: transaction, amount_applied: 300)
      create(:goal_transaction, goal: goal2, txn: transaction, amount_applied: 200)

      goal1.reload
      goal2.reload

      expect(goal1.current_amount).to eq(300)
      expect(goal2.current_amount).to eq(200)
    end

    it "updates both goals when amounts change" do
      gt1 = create(:goal_transaction, goal: goal1, txn: transaction, amount_applied: 300)
      gt2 = create(:goal_transaction, goal: goal2, txn: transaction, amount_applied: 200)

      gt1.update(amount_applied: 400)

      goal1.reload
      goal2.reload

      expect(goal1.current_amount).to eq(400)
      expect(goal2.current_amount).to eq(200)
    end
  end

  describe "optional notes" do
    it "allows notes to be nil" do
      goal_transaction.notes = nil
      expect(goal_transaction).to be_valid
    end

    it "allows notes to be set" do
      goal_transaction.notes = "This contribution is for the vacation budget"
      expect(goal_transaction).to be_valid
      expect(goal_transaction.notes).to eq("This contribution is for the vacation budget")
    end
  end
end
