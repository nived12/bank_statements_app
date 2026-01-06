# frozen_string_literal: true

##
# Debts::Updater
# Updates an existing debt
#
class Debts::Updater < ApplicationService
  def initialize(debt, debt_params)
    super()
    @debt = debt
    @debt_params = debt_params.to_h.deep_transform_values(&:presence)
  end

  def call
    # Extract category and bank account IDs to set before update
    category_ids = @debt_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @debt_params.delete(:bank_account_ids)&.compact_blank || []

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      # Set associations BEFORE update (ensures validation passes if auto_sync is being enabled)
      @debt.category_ids = category_ids
      @debt.bank_account_ids = bank_account_ids
      @debt.update!(@debt_params)
    end

    success(@debt)
  rescue ActiveRecord::RecordInvalid
    # Add validation errors to the service's error bag
    @debt.errors.each do |error|
      errors.add(error.attribute, error.message)
    end

    # Return the debt object as payload for error display
    Response.new(success: false, payload: @debt, errors: errors)
  end

  private

  attr_reader :debt, :debt_params
end
