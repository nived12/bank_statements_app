# frozen_string_literal: true

##
# Savings::CreateService
# Creates a new saving
#
class Savings::CreateService < ApplicationService
  def initialize(saving_params)
    super()
    @saving_params = saving_params
  end

  def call
    # Extract category and bank account IDs to set after creation
    category_ids = @saving_params.delete(:category_ids)&.reject(&:blank?) || []
    bank_account_ids = @saving_params.delete(:bank_account_ids)&.reject(&:blank?) || []

    @saving = Saving.new(@saving_params)

    # Validate that if auto_sync is enabled, we have categories and bank accounts
    if @saving.auto_sync_transactions?
      if category_ids.empty?
        @saving.errors.add(:base, :categories_required_for_auto_sync, message: "At least one category is required when auto-sync is enabled")
      end
      if bank_account_ids.empty?
        @saving.errors.add(:base, :bank_accounts_required_for_auto_sync, message: "At least one bank account is required when auto-sync is enabled")
      end
      return failure(@saving.errors) if @saving.errors.any?
    end

    if @saving.save
      # Set associations after successful save
      @saving.category_ids = category_ids
      @saving.bank_account_ids = bank_account_ids
      success(@saving)
    else
      failure(@saving.errors)
    end
  end

  private

  attr_reader :saving_params
end
