# frozen_string_literal: true

##
# Transactions::CreateService
# Service for creating manual transactions without statement files
#
class Transactions::CreateService < ApplicationService
  def initialize(transaction_params)
    super()
    @transaction_params = transaction_params
  end

  def call
    validate_required_params
    return failure if has_errors?

    create_transaction
    return failure if has_errors?

    success(transaction)
  end

  private

  attr_reader :transaction_params, :transaction

  def validate_required_params
    required_fields = %i[bank_account_id date description amount transaction_type]
    missing_fields = required_fields - transaction_params.keys.map(&:to_sym)

    if missing_fields.any?
      errors.add(:base, "Missing required fields: #{missing_fields.join(', ')}")
    end
  end

  def create_transaction
    @transaction = Current.user.transactions.build(transaction_params)

    unless transaction.save
      transaction.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end
end
