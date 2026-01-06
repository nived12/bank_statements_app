# frozen_string_literal: true

##
# Savings::Updater
# Updates an existing saving
#
class Savings::Updater < ApplicationService
  def initialize(saving, saving_params)
    super()
    @saving = saving
    @saving_params = saving_params.to_h.deep_transform_values(&:presence)
  end

  def call
    # Extract category and bank account IDs to set before update
    category_ids = @saving_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @saving_params.delete(:bank_account_ids)&.compact_blank || []

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      # Set associations BEFORE update (ensures validation passes if auto_sync is being enabled)
      @saving.category_ids = category_ids
      @saving.bank_account_ids = bank_account_ids
      @saving.update!(@saving_params)
    end

    success(@saving)
  rescue ActiveRecord::RecordInvalid
    # Add validation errors to the service's error bag
    @saving.errors.each do |error|
      errors.add(error.attribute, error.message)
    end

    # Return the saving object as payload for error display
    Response.new(success: false, payload: @saving, errors: errors)
  end

  private

  attr_reader :saving, :saving_params
end
