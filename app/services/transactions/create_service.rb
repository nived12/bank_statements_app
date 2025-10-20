# frozen_string_literal: true

##
# Transactions::CreateService
# Service for creating manual transactions without statement files
# Handles both regular transactions and transfers between accounts
#
class Transactions::CreateService < ApplicationService
  include Transactions::Concerns::Transferable

  def initialize(transaction_params)
    super()
    @transaction_params = transaction_params
  end

  def call
    validate_required_params
    return failure if has_errors?

    # Extract goal_id before creating transaction
    goal_id = transaction_params.delete(:goal_id)

    ActiveRecord::Base.transaction do
      if is_transfer?
        create_transfer_pair
      else
        create_transaction
      end

      return failure if has_errors?

      # Manually link to goal if specified (failures here don't fail the transaction)
      if goal_id.present?
        link_to_goal(goal_id)
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
    end

    # Additional validation for transfers
    validate_transfer_params
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

  def link_to_goal(goal_id)
    goal = Current.user.goals.find_by(id: goal_id)

    unless goal
      # Log but don't fail the transaction creation
      Rails.logger.warn("Transaction #{transaction.id} not linked: goal #{goal_id} not found")
      return
    end

    # Skip if goal is not active
    unless goal.status_active?
      # Log but don't fail the transaction creation
      Rails.logger.warn("Transaction #{transaction.id} not linked: goal #{goal.id} is not active")
      return
    end

    # Calculate amount based on goal's settings
    amount_to_apply = goal.calculate_amount_for_transaction(transaction)

    # If amount is nil (ignore setting), skip linking
    # But log a warning since user explicitly requested it
    if amount_to_apply.nil?
      Rails.logger.warn(
        "Transaction #{transaction.id} not linked to goal #{goal.id}: " \
        "transaction type #{transaction.transaction_type} is set to 'ignore' in goal settings"
      )
      return
    end

    # Link the transaction
    result = Goals::LinkTransactionService.call(
      goal,
      transaction,
      amount_to_apply,
      notes: "Manually linked",
      manual: true
    )

    unless result.success?
      # Log linking errors but don't fail the transaction creation
      Rails.logger.error("Failed to link transaction #{transaction.id} to goal #{goal.id}: #{result.errors.full_messages.join(", ")}")
    end
  end
end
