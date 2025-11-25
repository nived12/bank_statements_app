# frozen_string_literal: true

##
# Debts::CreateService
# Creates a new debt
#
class Debts::CreateService < ApplicationService
  def initialize(debt_params)
    super()
    @debt_params = debt_params.to_h.deep_transform_values!(&:presence)
  end

  def call
    # Extract category and bank account IDs to set before creation
    category_ids = @debt_params.delete(:category_ids)&.reject(&:blank?) || []
    bank_account_ids = @debt_params.delete(:bank_account_ids)&.reject(&:blank?) || []

    @debt = Debt.new(@debt_params)

    # Set associations before validation
    @debt.category_ids = category_ids
    @debt.bank_account_ids = bank_account_ids

    return success(@debt) if @debt.save

    failure(@debt.errors)
  end

  private

  attr_reader :debt_params
end
