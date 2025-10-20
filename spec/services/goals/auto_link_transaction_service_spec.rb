# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::AutoLinkTransactionService, type: :service do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category) }

  describe "#call" do
    context "when transaction has no category" do
      let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: nil) }

      it "skips auto-linking" do
        result = described_class.call(transaction)
        expect(result).to be_success
      end
    end

    context "when transaction has no bank_account" do
      let(:transaction) { build(:transaction, user: user, bank_account: bank_account, category: category) }

      it "skips auto-linking" do
        # Test the service logic by mocking the condition
        allow(transaction).to receive(:bank_account_id).and_return(nil)

        result = described_class.call(transaction)
        expect(result).to be_success
      end
    end

    context "when no matching goals exist" do
      it "skips auto-linking" do
        result = described_class.call(transaction)
        expect(result).to be_success
      end
    end

    context "when matching goals exist" do
      let!(:goal) do
        create(:goal,
               user: user,
               bank_account: bank_account,
               category: category,
               auto_link_category: true,
               goal_calculation_settings: {
                 "income" => "positive",
                 "expense" => "negative",
                 "transfer_in" => "positive",
                 "transfer_out" => "negative"
               })
      end

      context "with income transaction" do
        let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

        it "links transaction with positive amount" do
          expect { described_class.call(transaction) }
            .to change { GoalTransaction.count }.by(1)

          goal_transaction = GoalTransaction.last
          expect(goal_transaction.goal).to eq(goal)
          expect(goal_transaction.txn).to eq(transaction)
          expect(goal_transaction.amount_applied).to eq(100.0)
          expect(goal_transaction.notes).to eq("Auto-linked")
        end
      end

      context "with expense transaction" do
        let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "variable_expense", amount: -50.0) }

        it "links transaction with negative amount (expense reduces goal)" do
          expect { described_class.call(transaction) }
            .to change { GoalTransaction.count }.by(1)

          goal_transaction = GoalTransaction.last
          expect(goal_transaction.goal).to eq(goal)
          expect(goal_transaction.txn).to eq(transaction)
          expect(goal_transaction.amount_applied).to eq(-50.0) # Negative because setting is "negative"
          expect(goal_transaction.notes).to eq("Auto-linked")
        end
      end


      context "when setting is 'ignore'" do
        let(:goal) do
          create(:goal,
                 user: user,
                 bank_account: bank_account,
                 category: category,
                 auto_link_category: true,
                 goal_calculation_settings: {
                   "income" => "ignore",
                   "expense" => "ignore",
                   "transfer_in" => "ignore",
                   "transfer_out" => "ignore"
                 })
        end
        let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

        it "does not link transaction" do
          # Manually set the settings after creation to avoid default override
          goal.update_column(:goal_calculation_settings, {
            "income" => "ignore",
            "expense" => "ignore",
            "transfer_in" => "ignore",
            "transfer_out" => "ignore"
          })

          expect { described_class.call(transaction) }
            .not_to change { GoalTransaction.count }
        end
      end

      context "when setting is 'negative'" do
        let(:goal) do
          create(:goal,
                 user: user,
                 bank_account: bank_account,
                 category: category,
                 auto_link_category: true,
                 goal_calculation_settings: {
                   "income" => "negative",
                   "expense" => "negative",
                   "transfer_in" => "negative",
                   "transfer_out" => "negative"
                 })
        end
        let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

        it "links transaction with negative amount (negative setting)" do
          expect { described_class.call(transaction) }
            .to change { GoalTransaction.count }.by(1)

          goal_transaction = GoalTransaction.last
          expect(goal_transaction.goal).to eq(goal)
          expect(goal_transaction.txn).to eq(transaction)
          expect(goal_transaction.amount_applied).to eq(-100.0) # Negative because setting is "negative"
          expect(goal_transaction.notes).to eq("Auto-linked")
        end
      end

      context "when transaction is outside goal date range" do
        let(:goal) do
          create(:goal,
                 user: user,
                 bank_account: bank_account,
                 category: category,
                 auto_link_category: true,
                 start_date: 1.month.from_now,
                 deadline: 2.months.from_now)
        end

        it "does not link transaction" do
          expect { described_class.call(transaction) }
            .not_to change { GoalTransaction.count }
        end
      end

      context "when goal is not active" do
        let(:goal) do
          create(:goal,
                 user: user,
                 bank_account: bank_account,
                 category: category,
                 auto_link_category: true,
                 status: "completed")
        end

        it "does not link transaction" do
          expect { described_class.call(transaction) }
            .not_to change { GoalTransaction.count }
        end
      end

      context "when goal does not have auto_link enabled" do
        let(:goal) do
          create(:goal,
                 user: user,
                 bank_account: bank_account,
                 category: category,
                 auto_link_category: false)
        end

        it "does not link transaction" do
          expect { described_class.call(transaction) }
            .not_to change { GoalTransaction.count }
        end
      end

      context "when transaction is already linked" do
        let(:isolated_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

        it "does not create duplicate link" do
          # Create the link bypassing validation using insert
          GoalTransaction.insert({
            goal_id: goal.id,
            transaction_id: isolated_transaction.id,
            amount_applied: 50.0,
            notes: "Test link",
            created_at: Time.current,
            updated_at: Time.current
          })

          # The service should skip linking if already linked
          expect { described_class.call(isolated_transaction) }
            .not_to change { GoalTransaction.count }
        end
      end

      context "when transaction is already manually linked" do
        let(:manually_linked_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

        before do
          # Clear any auto-links that were created when transaction was first created
          manually_linked_transaction.goal_transactions.where(manual: false).destroy_all

          # Use insert to bypass uniqueness validation
          GoalTransaction.insert({
            goal_id: goal.id,
            transaction_id: manually_linked_transaction.id,
            amount_applied: 50.0,
            notes: "Manually linked",
            manual: true,
            created_at: Time.current,
            updated_at: Time.current
          })
        end

        it "skips auto-linking to prevent duplicates" do
          manually_linked_transaction.reload # Reload to see the inserted goal_transaction
          expect { described_class.call(manually_linked_transaction) }
            .not_to change { GoalTransaction.count }
        end

        it "does not create auto-linked goal_transaction" do
          manually_linked_transaction.reload # Reload to see the inserted goal_transaction
          described_class.call(manually_linked_transaction)

          auto_linked = manually_linked_transaction.goal_transactions.where(manual: false)
          expect(auto_linked).to be_empty
        end
      end

      context "with multiple matching goals" do
        let!(:goal2) do
          create(:goal,
                 user: user,
                 bank_account: bank_account,
                 category: category,
                 auto_link_category: true,
                 goal_calculation_settings: {
                   "income" => "positive",
                   "expense" => "negative",
                   "transfer_in" => "positive",
                   "transfer_out" => "negative"
                 })
        end
        let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", amount: 100.0) }

        it "links to all matching goals" do
          expect { described_class.call(transaction) }
            .to change { GoalTransaction.count }.by(2)

          goal_transactions = GoalTransaction.last(2)
          expect(goal_transactions.map(&:goal)).to contain_exactly(goal, goal2)
          expect(goal_transactions.map(&:txn)).to all(eq(transaction))
          expect(goal_transactions.map(&:amount_applied)).to all(eq(100.0))
        end
      end
  end
  end
end
