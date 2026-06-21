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
    # Extract category and bank account IDs to assign after the debt has an id
    category_ids = @debt_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @debt_params.delete(:bank_account_ids)&.compact_blank || []

    # auto_sync requires categories + bank accounts, but those join records
    # can only be attached once the debt has an id. So save first with
    # auto_sync off, attach the associations, then re-enable it so the
    # auto_sync validation runs against the now-present associations.
    wants_auto_sync = ActiveModel::Type::Boolean.new.cast(@debt_params.delete(:auto_sync_transactions))
    @debt = Debt.new(@debt_params)

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      @debt.auto_sync_transactions = false
      @debt.save!
      @debt.category_ids = category_ids
      @debt.bank_account_ids = bank_account_ids
      @debt.update!(auto_sync_transactions: true) if wants_auto_sync
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
