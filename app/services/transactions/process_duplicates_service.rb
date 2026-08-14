class Transactions::ProcessDuplicatesService < ApplicationService
  def initialize(user, statement_file_id, selected_transaction_ids)
    super()
    @user = user
    @statement_file_id = statement_file_id
    @selected_transaction_ids = selected_transaction_ids.map(&:to_i)
  end

  def call
    statement_file = @user.statement_files.find(@statement_file_id)
    pending_transactions = statement_file.pending_transactions.includes(:user, :bank_account)

    processed_count = 0

    # Group pending transactions by duplicate groups
    duplicate_groups = group_pending_transactions(pending_transactions)

    duplicate_groups.each do |group|
      # Find selected and deselected transactions in this group
      selected_transactions = group.select { |pt| @selected_transaction_ids.include?(pt.id) }
      deselected_transactions = group.reject { |pt| @selected_transaction_ids.include?(pt.id) }

      # Process selected transactions
      selected_transactions.each do |selected_transaction|
        if selected_transaction.source == "statement_file"
          # Create new transaction from statement file
          create_transaction_from_pending(selected_transaction)
          processed_count += 1
        elsif selected_transaction.source == "manual"
          # Keep the original manual transaction (it already exists)
          # Just ensure it's linked to the statement file
          original_transaction = find_original_manual_transaction(selected_transaction)
          if original_transaction
            original_transaction.update!(statement_file: statement_file)
            processed_count += 1
          end
        end
      end

      # Process deselected transactions
      deselected_transactions.each do |deselected_transaction|
        if deselected_transaction.source == "manual"
          # Delete the original manual transaction
          delete_original_manual_transaction(deselected_transaction)
        end
        # For statement_file transactions, we simply don't create them
      end
    end

    # Clean up all pending transactions for this statement file
    statement_file.pending_transactions.destroy_all

    # Mark statement file as completed
    statement_file.update(status: :completed)

    success(processed_count: processed_count)
  end

  private

  def group_pending_transactions(pending_transactions)
    # Group by user, bank_account, date, amount to find duplicate groups
    pending_transactions.group_by do |pt|
      [ pt.user_id, pt.bank_account_id, pt.date, pt.amount ]
    end.values
  end

  def create_transaction_from_pending(pending_transaction)
    Transaction.create!(
      user: pending_transaction.user,
      bank_account: pending_transaction.bank_account,
      statement_file: pending_transaction.statement_file,
      date: pending_transaction.date,
      description: pending_transaction.description,
      concept: pending_transaction.concept,
      amount: pending_transaction.amount,
      transaction_type: pending_transaction.transaction_type,
      category_id: pending_transaction.category_id,
      merchant: pending_transaction.merchant,
      reference: pending_transaction.reference,
      tracking_key: pending_transaction.tracking_key,
      confidence: pending_transaction.confidence,
      category_confidence: pending_transaction.category_confidence,
      transaction_type_confidence: pending_transaction.transaction_type_confidence,
      source: pending_transaction.source
    )
  end

  def find_original_manual_transaction(pending_transaction)
    # Find the original manual transaction that was duplicated
    Transaction.find_by(
      user: pending_transaction.user,
      bank_account: pending_transaction.bank_account,
      date: pending_transaction.date,
      amount: pending_transaction.amount,
      description: pending_transaction.description,
      source: :manual
    )
  end

  def delete_original_manual_transaction(pending_transaction)
    # Find the original manual transaction that was duplicated
    original_transaction = Transaction.find_by(
      user: pending_transaction.user,
      bank_account: pending_transaction.bank_account,
      date: pending_transaction.date,
      amount: pending_transaction.amount,
      description: pending_transaction.description,
      source: :manual
    )

    original_transaction&.destroy
  end
end
