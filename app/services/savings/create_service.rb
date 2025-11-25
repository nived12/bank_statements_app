# frozen_string_literal: true

##
# Savings::CreateService
# Creates a new saving
#
class Savings::CreateService < ApplicationService
  def initialize(saving_params)
    super()
    @saving_params = saving_params.to_h.deep_transform_values!(&:presence)
  end

  def call
    # Extract category and bank account IDs to set before creation
    category_ids = @saving_params.delete(:category_ids)&.reject(&:blank?) || []
    bank_account_ids = @saving_params.delete(:bank_account_ids)&.reject(&:blank?) || []

    @saving = Saving.new(@saving_params)

    # Set associations before validation
    @saving.category_ids = category_ids
    @saving.bank_account_ids = bank_account_ids

    return success(@saving) if @saving.save

    failure(@saving.errors)
  end

  private

  attr_reader :saving_params
end
