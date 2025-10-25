# frozen_string_literal: true

##
# Debts::CreateService
# Creates a new debt
#
class Debts::CreateService < ApplicationService
  def initialize(debt_params)
    super()
    @debt_params = debt_params
  end

  def call
    # Extract category and bank account IDs to set after creation
    category_ids = @debt_params.delete(:category_ids)&.reject(&:blank?) || []
    bank_account_ids = @debt_params.delete(:bank_account_ids)&.reject(&:blank?) || []

    @debt = Debt.new(@debt_params)

    # Validate that if auto_sync is enabled, we have categories and bank accounts
    if @debt.auto_sync_transactions?
      if category_ids.empty?
        @debt.errors.add(:base, :categories_required_for_auto_sync, message: "At least one category is required when auto-sync is enabled")
      end
      if bank_account_ids.empty?
        @debt.errors.add(:base, :bank_accounts_required_for_auto_sync, message: "At least one bank account is required when auto-sync is enabled")
      end
      return failure(@debt.errors) if @debt.errors.any?
    end

    if @debt.save
      # Set associations after successful save
      @debt.category_ids = category_ids
      @debt.bank_account_ids = bank_account_ids
      success(@debt)
    else
      failure(@debt.errors)
    end
  end

  private

  attr_reader :debt_params
end
