# frozen_string_literal: true

##
# Savings::Creator
# Creates a new saving
#
class Savings::Creator < ApplicationService
  def initialize(saving_params)
    super()
    @saving_params = saving_params.to_h.deep_transform_values(&:presence)
  end

  def call
    # Extract category and bank account IDs to set after creation
    category_ids = @saving_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @saving_params.delete(:bank_account_ids)&.compact_blank || []

    @saving = Saving.new(@saving_params)

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      @saving.save!
      @saving.category_ids = category_ids
      @saving.bank_account_ids = bank_account_ids
    end

    success(@saving)
  rescue ActiveRecord::RecordInvalid => e
    # Add validation errors to the service's error bag
    @saving.errors.each do |error|
      errors.add(error.attribute, error.message)
    end

    # Return the unsaved saving object as payload for error display
    Response.new(success: false, payload: @saving, errors: errors)
  end

  private

  attr_reader :saving_params
end
