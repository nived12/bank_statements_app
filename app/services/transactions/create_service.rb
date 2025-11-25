# frozen_string_literal: true

##
# Transactions::CreateService
# Service for creating manual transactions without statement files
# Handles both regular transactions and transfers between accounts
#
class Transactions::CreateService < ApplicationService
  include Transactions::Concerns::Transferable
  include Transactions::Concerns::SavingsDebtsLinkable

  def initialize(transaction_params)
    super()
    @transaction_params = transaction_params
  end

  def call
    validate_transfer_params
    return failure if has_errors?

    # Ensure amount has correct sign based on transaction type
    normalize_amount_sign

    # Extract saving_ids and debt_ids before creating transaction
    saving_ids = transaction_params.delete(:saving_ids)
    debt_ids = transaction_params.delete(:debt_ids)

    ActiveRecord::Base.transaction do
      if is_transfer?
        create_transfer_pair
      else
        create_transaction
      end

      return failure if has_errors?

      # Manually link to savings and debts if specified (failures here don't fail the transaction)
      if saving_ids.present?
        link_to_savings(transaction, saving_ids)
      end
      if debt_ids.present?
        link_to_debts(transaction, debt_ids)
      end
    end

    success(transaction)
  end

  private

  attr_reader :transaction_params, :transaction

  def create_transaction
    @transaction = Current.user.transactions.build(transaction_params.except(:transfer_account_id))
    @transaction.source = :manual

    unless transaction.save
      transaction.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end

  # Apply correct sign based on transaction type
  def normalize_amount_sign
    return unless transaction_params[:amount].present?

    amount = transaction_params[:amount].to_d.abs.round(2)
    transaction_type = transaction_params[:transaction_type]

    transaction_params[:amount] =
      if %w[fixed_expense variable_expense transfer_out].include? transaction_type
        -amount
      else
        amount
      end
  end
end
