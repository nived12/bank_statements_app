# frozen_string_literal: true

##
# Savings::Creator
# Creates a new saving
#
class Savings::Creator < ApplicationService
  def initialize(saving_params)
    super()
    # Only blank strings become nil. Bare `&:presence` also turned false into
    # nil, and auto_sync_transactions is NOT NULL — every mobile edit of a
    # record with auto-sync off raised a 500.
    @saving_params = saving_params.to_h.deep_transform_values { |value| value.is_a?(String) ? value.presence : value }
  end

  def call
    # Extract category and bank account IDs to assign before save
    category_ids = @saving_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @saving_params.delete(:bank_account_ids)&.compact_blank || []

    # auto_sync requires categories + bank accounts, but those join records
    # can only be attached once the saving has an id. So save first with
    # auto_sync off, attach the associations, then re-enable it so the
    # auto_sync validation runs against the now-present associations.
    wants_auto_sync = ActiveModel::Type::Boolean.new.cast(@saving_params.delete(:auto_sync_transactions))
    @saving = Saving.new(@saving_params)
    linked = 0

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      @saving.auto_sync_transactions = false
      @saving.save!
      @saving.category_ids = category_ids
      @saving.bank_account_ids = bank_account_ids
      if wants_auto_sync
        @saving.update!(auto_sync_transactions: true)
        # Auto-sync only fires on Transaction#after_commit, so a saving created with it
        # already on links nothing until the next matching transaction is saved. Claim
        # its existing matches now.
        linked = Savings::TransactionBackfiller.call(@saving).payload.to_i
      end
    end

    if linked.positive?
      @saving.reload
      @saving.backfill_summary = { linked: linked, unlinked: 0 }
    end

    success(@saving)
  rescue ActiveRecord::RecordInvalid
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
