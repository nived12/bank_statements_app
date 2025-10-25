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
    @debt.category_ids = category_ids
    @debt.bank_account_ids = bank_account_ids

    if @debt.save
      success(@debt)
    else
      failure(@debt.errors)
    end
  end

  private

  attr_reader :debt_params
end
