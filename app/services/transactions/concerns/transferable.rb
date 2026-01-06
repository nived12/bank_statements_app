# frozen_string_literal: true

module Transactions
  module Concerns
    ##
    # Transferable
    # Concern for handling transfer transactions between bank accounts
    #
    module Transferable
      extend ActiveSupport::Concern

      private

      def is_transfer?
        transaction_params[:transaction_type] == "transfer_out"
      end

      def validate_transfer_params
        return unless is_transfer?

        if transaction_params[:transfer_account_id].blank?
          errors.add(
            :transfer_account_id,
            I18n.t("activerecord.errors.models.transaction.attributes.transfer_account_id.required")
          )
        end

        # Prevent self-transfers
        if transaction_params[:transfer_account_id].to_i == transaction_params[:bank_account_id].to_i
          errors.add(
            :transfer_account_id,
            I18n.t("activerecord.errors.models.transaction.attributes.transfer_account_id.same_as_source")
          )
        end
      end

      def create_transfer_pair
        transfer_account = Current.user.bank_accounts.find_by(id: transaction_params[:transfer_account_id])

        unless transfer_account
          errors.add(
            :transfer_account_id,
            I18n.t("activerecord.errors.models.transaction.attributes.transfer_account_id.not_found")
          )
          return
        end

        # bank_account_id = source (transfer out, negative)
        # transfer_account_id = destination (transfer in, positive)
        source_account_id = transaction_params[:bank_account_id]
        destination_account_id = transaction_params[:transfer_account_id]
        amount_value = transaction_params[:amount].to_d.abs.round(2)

        ActiveRecord::Base.transaction do
          # Create transfer OUT transaction (source account, negative)
          @transaction = Current.user.transactions.build(
            bank_account_id: source_account_id,
            date: transaction_params[:date],
            description: transaction_params[:description],
            amount: -amount_value, # Negative for outgoing
            transaction_type: :transfer_out,
            category_id: transaction_params[:category_id],
            merchant: transaction_params[:merchant],
            reference: transaction_params[:reference],
            source: :manual
          )

          # Create transfer IN transaction (destination account, positive)
          paired_transaction = Current.user.transactions.build(
            bank_account_id: destination_account_id,
            date: transaction_params[:date],
            description: transaction_params[:description],
            amount: amount_value, # Positive for incoming
            transaction_type: :transfer_in,
            category_id: transaction_params[:category_id],
            merchant: transaction_params[:merchant],
            reference: transaction_params[:reference],
            source: :manual
          )

          # Save both without validation first (to avoid linked_transfer_id requirement)
          unless transaction.save(validate: false) && paired_transaction.save(validate: false)
            add_transaction_errors(transaction)
            add_transaction_errors(paired_transaction)
            raise ActiveRecord::Rollback
          end

          # Link them together
          transaction.update_column(:linked_transfer_id, paired_transaction.id)
          paired_transaction.update_column(:linked_transfer_id, transaction.id)

          # Now validate
          unless transaction.valid? && paired_transaction.valid?
            add_transaction_errors(transaction)
            add_transaction_errors(paired_transaction)
            raise ActiveRecord::Rollback
          end
        end
      end

      def add_transaction_errors(trans)
        return unless trans&.errors&.any?

        trans.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
      end

      # Sync changes from a transfer to its linked transfer
      def sync_to_linked_transfer(transaction, params)
        # Only sync if this is a transfer and has a linked transfer
        return unless transaction.transfer?
        return unless transaction.linked_transfer

        # Prepare attributes to sync (all editable fields except amount)
        sync_params = {}

        # Sync these fields directly if they were updated
        %i[date description category_id merchant reference].each do |field|
          sync_params[field] = params[field] if params.key?(field)
        end

        # Sync amount with opposite sign
        if params.key?(:amount)
          sync_params[:amount] = -params[:amount].to_d.round(2)
        end

        # Update the linked transfer if there are any changes to sync
        return if sync_params.empty?

        unless transaction.linked_transfer.update(sync_params)
          errors.add(:base, I18n.t("transactions.errors.failed_to_sync_transfer"))
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
