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
    @debt = Debt.new(@debt_params)

    if @debt.save
      success(@debt)
    else
      failure(@debt.errors)
    end
  end

  private

  attr_reader :debt_params
end
