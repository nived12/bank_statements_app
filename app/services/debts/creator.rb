# frozen_string_literal: true

##
# Debts::Creator
# Creates a new debt
#
class Debts::Creator < ApplicationService
  def initialize(debt_params)
    super()
    @debt_params = debt_params.to_h.deep_transform_values(&:presence)
  end

  def call
    # Extract category and bank account IDs to set after creation
    category_ids = @debt_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @debt_params.delete(:bank_account_ids)&.compact_blank || []

    @debt = Debt.new(@debt_params)

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      @debt.save!
      @debt.category_ids = category_ids
      @debt.bank_account_ids = bank_account_ids
    end

    success(@debt)
  rescue ActiveRecord::RecordInvalid
    # Add validation errors to the service's error bag
    @debt.errors.each do |error|
      errors.add(error.attribute, error.message)
    end

    # Return the unsaved debt object as payload for error display
    Response.new(success: false, payload: @debt, errors: errors)
  end

  private

  attr_reader :debt_params
end
