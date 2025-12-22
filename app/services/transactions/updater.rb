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

    success(transaction)
  end

  private

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
end
