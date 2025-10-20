# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Goal Linking Integration', type: :feature do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user, name: 'Salary') }

  before do
    Current.user = user
  end

  after do
    Current.reset
  end

  describe 'Manual goal linking flow' do
    let!(:savings_goal) do
      create(:goal,
             user: user,
             name: 'Emergency Fund',
             target_amount: 10000,
             current_amount: 0,
             start_date: 1.month.ago.to_date,
             deadline: 6.months.from_now.to_date,
             goal_calculation_settings: {
               'income' => 'positive',
               'expense' => 'ignore',
               'transfer_in' => 'positive',
               'transfer_out' => 'ignore'
             })
    end

    context 'when creating a transaction with goal_id' do
      it 'creates transaction, links to goal, and updates goal progress' do
        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Monthly salary',
          amount: 5000,
          transaction_type: 'income',
          category_id: category.id,
          goal_ids: [savings_goal.id]
        }).permit!

        # Create transaction with manual goal link
        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify transaction was created
        expect(transaction).to be_persisted
        expect(transaction.description).to eq('Monthly salary')
        expect(transaction.amount).to eq(5000)

        # Verify GoalTransaction was created with correct attributes
        expect(transaction.goal_transactions.count).to eq(1)
        goal_transaction = transaction.goal_transactions.first
        expect(goal_transaction.goal).to eq(savings_goal)
        expect(goal_transaction.amount_applied).to eq(5000)
        expect(goal_transaction.notes).to eq('Manually linked')

        # Verify goal current_amount was updated
        expect(savings_goal.reload.current_amount).to eq(5000)
      end

      it 'handles negative amounts correctly for debt payoff goals' do
        debt_goal = create(:goal,
                          user: user,
                          name: 'Credit Card Debt',
                          goal_type: 'debt_payoff',
                          target_amount: 0,
                          starting_debt_amount: 10000,
                          current_amount: 0,
                          debt_strategy: 'snowball',
                          start_date: 1.month.ago.to_date,
                          deadline: 12.months.from_now.to_date,
                          goal_calculation_settings: {
                            'income' => 'ignore',
                            'expense' => 'negative',
                            'transfer_in' => 'ignore',
                            'transfer_out' => 'negative'
                          })

        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Credit card payment',
          amount: -500,
          transaction_type: 'variable_expense',
          category_id: category.id,
          goal_ids: [debt_goal.id]
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify goal transaction
        goal_transaction = transaction.goal_transactions.first
        expect(goal_transaction.amount_applied).to eq(-500) # Negative because setting is "negative"
        expect(goal_transaction.notes).to eq('Manually linked')

        # Verify debt goal decreased
        expect(debt_goal.reload.current_amount).to eq(-500)
      end
    end

    context 'when updating a transaction to add goal link' do
      let!(:transaction) do
        create(:transaction,
               user: user,
               bank_account: bank_account,
               category: category,
               transaction_type: 'income',
               amount: 3000,
               description: 'Bonus')
      end

      it 'links transaction to goal and updates goal progress' do
        update_params = ActionController::Parameters.new({
          goal_ids: [savings_goal.id]
        }).permit!

        result = Transactions::UpdateService.call(transaction.id, update_params)

        expect(result).to be_success

        # Verify GoalTransaction was created
        expect(transaction.reload.goal_transactions.count).to eq(1)
        goal_transaction = transaction.goal_transactions.first
        expect(goal_transaction.goal).to eq(savings_goal)
        expect(goal_transaction.amount_applied).to eq(3000)
        expect(goal_transaction.notes).to eq('Manually linked')

        # Verify goal was updated
        expect(savings_goal.reload.current_amount).to eq(3000)
      end

      it 'prevents duplicate manual links to the same goal' do
        # First link
        update_params = ActionController::Parameters.new({
          goal_ids: [savings_goal.id]
        }).permit!
        Transactions::UpdateService.call(transaction.id, update_params)

        expect(transaction.reload.goal_transactions.count).to eq(1)
        expect(savings_goal.reload.current_amount).to eq(3000)

        # Try to link again
        result = Transactions::UpdateService.call(transaction.id, update_params)

        expect(result).to be_success
        # Should still have only one link
        expect(transaction.reload.goal_transactions.count).to eq(1)
        # Goal amount should not double
        expect(savings_goal.reload.current_amount).to eq(3000)
      end
    end

    context 'when transaction date is outside goal range' do
      let!(:future_goal) do
        create(:goal,
               user: user,
               name: 'Future Vacation',
               target_amount: 5000,
               current_amount: 0,
               start_date: 3.months.from_now.to_date,
               deadline: 12.months.from_now.to_date,
               goal_calculation_settings: {
                 'income' => 'positive',
                 'expense' => 'ignore',
                 'transfer_in' => 'positive',
                 'transfer_out' => 'ignore'
               })
      end

      it 'still allows manual linking (user decision)' do
        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current, # Today, before goal start_date
          description: 'Early vacation savings',
          amount: 1000,
          transaction_type: 'income',
          category_id: category.id,
          goal_ids: [future_goal.id]
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify link was created despite date being outside range
        expect(transaction.goal_transactions.count).to eq(1)
        goal_transaction = transaction.goal_transactions.first
        expect(goal_transaction.goal).to eq(future_goal)
        expect(goal_transaction.notes).to eq('Manually linked')

        # Verify goal was updated
        expect(future_goal.reload.current_amount).to eq(1000)
      end
    end

    context 'when transaction type is set to ignore in goal settings' do
      it 'skips linking but logs warning' do
        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Expense transaction',
          amount: -200,
          transaction_type: 'variable_expense', # This is set to 'ignore'
          category_id: category.id,
          goal_ids: [savings_goal.id]
        }).permit!

        expect(Rails.logger).to receive(:warn).with(/transaction type variable_expense is set to 'ignore'/)

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify no link was created
        expect(transaction.goal_transactions).to be_empty

        # Verify goal was not updated
        expect(savings_goal.reload.current_amount).to eq(0)
      end
    end

    context 'when goal is not active' do
      before do
        savings_goal.update(status: 'completed')
      end

      it 'does not link transaction to inactive goal' do
        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Income after goal completed',
          amount: 1000,
          transaction_type: 'income',
          category_id: category.id,
          goal_ids: [savings_goal.id]
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify no link was created
        expect(transaction.goal_transactions).to be_empty

        # Verify goal was not updated
        expect(savings_goal.reload.current_amount).to eq(0)
      end
    end
  end

  describe 'Auto-linking flow' do
    let!(:auto_link_goal) do
      create(:goal,
             user: user,
             bank_account: bank_account,
             category: category,
             name: 'Salary Savings',
             target_amount: 20000,
             current_amount: 0,
             auto_link_category: true,
             start_date: 1.month.ago.to_date,
             deadline: 12.months.from_now.to_date,
             goal_calculation_settings: {
               'income' => 'positive',
               'expense' => 'negative',
               'transfer_in' => 'positive',
               'transfer_out' => 'negative'
             })
    end

    context 'when transaction matches auto-link criteria' do
      it 'automatically links transaction to goal' do
        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Salary payment',
          amount: 5000,
          transaction_type: 'income',
          category_id: category.id
          # Note: no goal_id provided
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify auto-link happened
        expect(transaction.goal_transactions.count).to eq(1)
        goal_transaction = transaction.goal_transactions.first
        expect(goal_transaction.goal).to eq(auto_link_goal)
        expect(goal_transaction.amount_applied).to eq(5000)
        expect(goal_transaction.notes).to eq('Auto-linked')

        # Verify goal was updated
        expect(auto_link_goal.reload.current_amount).to eq(5000)
      end

      it 'links to multiple matching goals' do
        # Create a second auto-link goal with same criteria
        second_goal = create(:goal,
                            user: user,
                            bank_account: bank_account,
                            category: category,
                            name: 'Investment Fund',
                            target_amount: 15000,
                            current_amount: 0,
                            auto_link_category: true,
                            start_date: 1.month.ago.to_date,
                            deadline: 12.months.from_now.to_date,
                            goal_calculation_settings: {
                              'income' => 'positive',
                              'expense' => 'negative',
                              'transfer_in' => 'positive',
                              'transfer_out' => 'negative'
                            })

        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Salary payment',
          amount: 5000,
          transaction_type: 'income',
          category_id: category.id
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify both goals were auto-linked
        expect(transaction.goal_transactions.count).to eq(2)
        linked_goals = transaction.goal_transactions.map(&:goal)
        expect(linked_goals).to contain_exactly(auto_link_goal, second_goal)

        # Verify both goals were updated
        expect(auto_link_goal.reload.current_amount).to eq(5000)
        expect(second_goal.reload.current_amount).to eq(5000)
      end
    end

    context 'when transaction does not match auto-link criteria' do
      it 'does not auto-link when category is different' do
        other_category = create(:category, user: user, name: 'Other')

        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Other income',
          amount: 5000,
          transaction_type: 'income',
          category_id: other_category.id
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify no auto-link happened
        expect(transaction.goal_transactions).to be_empty

        # Verify goal was not updated
        expect(auto_link_goal.reload.current_amount).to eq(0)
      end

      it 'does not auto-link when bank account is different' do
        other_bank_account = create(:bank_account, user: user)

        transaction_params = ActionController::Parameters.new({
          bank_account_id: other_bank_account.id,
          date: Date.current,
          description: 'Salary from other account',
          amount: 5000,
          transaction_type: 'income',
          category_id: category.id
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify no auto-link happened
        expect(transaction.goal_transactions).to be_empty

        # Verify goal was not updated
        expect(auto_link_goal.reload.current_amount).to eq(0)
      end

      it 'does not auto-link when date is outside goal range' do
        transaction_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: 2.months.ago.to_date, # Before goal start_date
          description: 'Old salary',
          amount: 5000,
          transaction_type: 'income',
          category_id: category.id
        }).permit!

        result = Transactions::CreateService.call(transaction_params)

        expect(result).to be_success
        transaction = result.payload

        # Verify no auto-link happened
        expect(transaction.goal_transactions).to be_empty

        # Verify goal was not updated
        expect(auto_link_goal.reload.current_amount).to eq(0)
      end
    end
  end

  describe 'Manual link prevents auto-link' do
    let!(:auto_link_goal) do
      create(:goal,
             user: user,
             bank_account: bank_account,
             category: category,
             name: 'Auto Savings',
             target_amount: 10000,
             current_amount: 0,
             auto_link_category: true,
             start_date: 1.month.ago.to_date,
             deadline: 12.months.from_now.to_date,
             goal_calculation_settings: {
               'income' => 'positive',
               'expense' => 'negative',
               'transfer_in' => 'positive',
               'transfer_out' => 'negative'
             })
    end

    let!(:manual_goal) do
      create(:goal,
             user: user,
             name: 'Manual Goal',
             target_amount: 5000,
             current_amount: 0,
             auto_link_category: false, # Not auto-linking
             start_date: 1.month.ago.to_date,
             deadline: 12.months.from_now.to_date,
             goal_calculation_settings: {
               'income' => 'positive',
               'expense' => 'ignore',
               'transfer_in' => 'positive',
               'transfer_out' => 'ignore'
             })
    end

    it 'does not auto-link when transaction is manually linked' do
      # Create transaction with manual link
      transaction_params = ActionController::Parameters.new({
        bank_account_id: bank_account.id,
        date: Date.current,
        description: 'Salary with manual link',
        amount: 5000,
        transaction_type: 'income',
        category_id: category.id,
        goal_ids: [manual_goal.id] # Manually link to manual_goal
      }).permit!

      result = Transactions::CreateService.call(transaction_params)

      expect(result).to be_success
      transaction = result.payload

      # Verify only manual link exists (no auto-link happened)
      expect(transaction.goal_transactions.count).to eq(1)
      goal_transaction = transaction.goal_transactions.first
      expect(goal_transaction.goal).to eq(manual_goal)
      expect(goal_transaction.notes).to eq('Manually linked')

      # Verify only manual goal was updated
      expect(manual_goal.reload.current_amount).to eq(5000)
      expect(auto_link_goal.reload.current_amount).to eq(0)
    end

    it 'allows switching from one manual goal to another' do
      # Create transaction with first manual link
      transaction_params = ActionController::Parameters.new({
        bank_account_id: bank_account.id,
        date: Date.current,
        description: 'Income',
        amount: 3000,
        transaction_type: 'income',
        category_id: category.id,
        goal_ids: [manual_goal.id]
      }).permit!

      result = Transactions::CreateService.call(transaction_params)
      transaction = result.payload

      expect(manual_goal.reload.current_amount).to eq(3000)

      # Now update to link to a different goal
      other_goal = create(:goal,
                         user: user,
                         name: 'Other Goal',
                         target_amount: 8000,
                         current_amount: 0,
                         start_date: 1.month.ago.to_date,
                         deadline: 12.months.from_now.to_date,
                         goal_calculation_settings: {
                           'income' => 'positive',
                           'expense' => 'ignore',
                           'transfer_in' => 'positive',
                           'transfer_out' => 'ignore'
                         })

      update_params = ActionController::Parameters.new({
        goal_ids: [other_goal.id]
      }).permit!

      update_result = Transactions::UpdateService.call(transaction.id, update_params)

      expect(update_result).to be_success

      # Verify new link was created
      transaction.reload
      expect(transaction.goal_transactions.where(notes: 'Manually linked').count).to eq(2)

      # Verify both goals were updated
      expect(manual_goal.reload.current_amount).to eq(3000)
      expect(other_goal.reload.current_amount).to eq(3000)
    end
  end

  describe 'Complete workflow: transaction lifecycle with goals' do
    let!(:savings_goal) do
      create(:goal,
             user: user,
             bank_account: bank_account,
             category: category,
             name: 'Vacation Fund',
             target_amount: 5000,
             current_amount: 0,
             auto_link_category: true,
             start_date: 1.month.ago.to_date,
             deadline: 6.months.from_now.to_date,
             goal_calculation_settings: {
               'income' => 'positive',
               'expense' => 'negative',
               'transfer_in' => 'positive',
               'transfer_out' => 'negative'
             })
    end

    it 'handles complete transaction lifecycle with auto-linking and manual updates' do
      # Step 1: Create transaction that auto-links
      transaction_params = ActionController::Parameters.new({
        bank_account_id: bank_account.id,
        date: Date.current,
        description: 'Monthly contribution',
        amount: 500,
        transaction_type: 'income',
        category_id: category.id
      }).permit!

      result = Transactions::CreateService.call(transaction_params)
      transaction = result.payload

      # Verify auto-link
      expect(transaction.goal_transactions.count).to eq(1)
      expect(transaction.goal_transactions.first.notes).to eq('Auto-linked')
      expect(savings_goal.reload.current_amount).to eq(500)

      # Step 2: Update transaction amount
      update_params = ActionController::Parameters.new({
        amount: 750
      }).permit!

      update_result = Transactions::UpdateService.call(transaction.id, update_params)
      expect(update_result).to be_success

      # Verify transaction amount was updated
      expect(transaction.reload.amount).to eq(750)

      # Verify auto-link was recalculated with new amount
      expect(transaction.goal_transactions.count).to eq(1)
      expect(transaction.goal_transactions.first.amount_applied).to eq(750)
      expect(savings_goal.reload.current_amount).to eq(750)

      # Step 3: Change transaction category (should break auto-link criteria)
      other_category = create(:category, user: user, name: 'Bonus')
      change_category_params = ActionController::Parameters.new({
        category_id: other_category.id
      }).permit!

      category_result = Transactions::UpdateService.call(transaction.id, change_category_params)
      expect(category_result).to be_success

      # Auto-link is removed because category changed (callback clears auto-links and re-evaluates)
      expect(transaction.reload.goal_transactions.count).to eq(0)

      # Step 4: Manually add link to another goal
      other_goal = create(:goal,
                         user: user,
                         name: 'Emergency Fund',
                         target_amount: 10000,
                         current_amount: 0,
                         start_date: 1.month.ago.to_date,
                         deadline: 12.months.from_now.to_date,
                         goal_calculation_settings: {
                           'income' => 'positive',
                           'expense' => 'ignore',
                           'transfer_in' => 'positive',
                           'transfer_out' => 'ignore'
                         })

      manual_link_params = ActionController::Parameters.new({
        goal_ids: [other_goal.id]
      }).permit!

      manual_result = Transactions::UpdateService.call(transaction.id, manual_link_params)
      expect(manual_result).to be_success

      # Now has only the manual link (auto-link was removed when category changed)
      transaction.reload
      expect(transaction.goal_transactions.count).to eq(1)
      expect(transaction.goal_transactions.where(manual: true).count).to eq(1)

      # Verify goal was updated
      expect(other_goal.reload.current_amount).to eq(750)
    end
  end
end
