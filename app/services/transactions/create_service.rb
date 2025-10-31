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
    validate_required_params
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

  def validate_required_params
    required_fields = %i[bank_account_id date description amount transaction_type]
    missing_fields = required_fields - transaction_params.keys.map(&:to_sym)

    if missing_fields.any?
      errors.add(:base, "Missing required fields: #{missing_fields.join(", ")}")
      return
    end

    # Validate amount value
    validate_amount

    # Validate date value
    validate_date

    # Additional validation for transfers
    validate_transfer_params
  end

  def validate_amount
    amount = transaction_params[:amount]

    # Check if amount is numeric
    unless amount.to_s.match?(/\A-?\d+(\.\d+)?\z/)
      errors.add(:amount, "must be a valid number")
      return
    end

    # Check if amount is zero
    if amount.to_f.zero?
      errors.add(:amount, "cannot be zero")
    end
  end

  def validate_date
    date_string = transaction_params[:date]

    begin
      Date.parse(date_string.to_s)
    rescue ArgumentError
      errors.add(:date, "must be a valid date")
    end
  end

  def create_transaction
    @transaction = Current.user.transactions.build(transaction_params.except(:transfer_account_id))
    @transaction.source = :manual

    unless transaction.save
      transaction.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end

  def normalize_amount_sign
    return unless transaction_params[:amount].present?

    amount = transaction_params[:amount].to_f.abs
    transaction_type = transaction_params[:transaction_type]

    # Apply correct sign based on transaction type
    transaction_params[:amount] = case transaction_type
    when "income"
      amount.abs  # Income is always positive
    when "fixed_expense", "variable_expense"
      -amount.abs  # Expenses are always negative
    when "transfer_out"
      -amount.abs  # Transfer out is negative (will be inverted for transfer_in pair)
    else
      amount  # Default: keep positive
    end
  end
end
