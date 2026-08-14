# frozen_string_literal: true

##
# Transactions::Updater
# Service for handling transaction updates
#
class Transactions::Updater < ApplicationService
  include Transactions::Concerns::SavingsDebtsLinkable
  include Transactions::Concerns::Transferable
  include Transactions::Concerns::AmountNormalizable

  def initialize(transaction_id, update_params)
    super()
    @transaction_id = transaction_id
    @update_params = update_params
  end

  def call
    find_transaction
    return failure unless transaction
    return reject_excluded if amount_or_type_change_on_excluded?

    # Extract saving_ids and debt_ids before updating transaction
    saving_ids = update_params.delete(:saving_ids)
    debt_ids = update_params.delete(:debt_ids)

    ActiveRecord::Base.transaction do
      update_transaction
      return failure if has_errors?

      # Handle manual savings and debts links
      update_savings_links(transaction, saving_ids)
      update_debts_links(transaction, debt_ids)
    end

    # Auto-generate category rule when category actually changed on statement-file transactions
    if should_create_category_rule?
      CategoryRules::Creator.call(transaction)
    end

    success(transaction)
  end

  private

  # An excluded row is one half of a self-cancelling pair taken straight from a
  # statement — a charge and the credit that undoes it. Its sign is not implied by
  # its type, so any edit path that derives one from the other (the inline row and
  # the full form both do) would flip the credit half negative and turn a pair that
  # nets to zero into a doubled expense. Category and notes stay editable; the two
  # fields that define the pair do not.
  def amount_or_type_change_on_excluded?
    return false unless transaction.ttype_excluded?

    update_params.key?(:amount) || update_params.key?(:transaction_type)
  end

  def reject_excluded
    errors.add(:base, I18n.t("transactions.errors.excluded_not_editable"))
    failure
  end

  attr_reader :transaction_id, :update_params, :transaction

  def find_transaction
    @transaction = Current.user.transactions.find_by(id: transaction_id)
    return if @transaction.present?

    errors.add(:base, I18n.t("transactions.errors.not_found"))
  end

  def update_transaction
    # Remove transfer_account_id as it's only used during creation
    filtered_params = update_params.except(:transfer_account_id)

    # Normalize amount sign based on transaction type
    normalize_amount_sign(filtered_params, transaction) if filtered_params.key?(:amount)

    # For transfers, preserve transaction_type and bank_account_id
    # These should never change as they define the transfer relationship
    filtered_params = filtered_params.except(:transaction_type, :bank_account_id) if transaction.transfer?

    ActiveRecord::Base.transaction do
      unless transaction.update(filtered_params)
        transaction.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        raise ActiveRecord::Rollback
      end

      # If this is a transfer, sync changes to linked transfer
      sync_to_linked_transfer(transaction, filtered_params)
    end
  rescue => e
    errors.add(:base, e.message)
  end

  def should_create_category_rule?
    update_params.key?(:category_id) &&
      transaction.category_id.present? &&
      transaction.saved_change_to_category_id? &&
      transaction.statement_file?
  end
end
