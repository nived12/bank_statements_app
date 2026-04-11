class BelvoSyncJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(belvo_link_id, date_from: nil, date_to: nil)
    belvo_link = BelvoLink.find(belvo_link_id)
    belvo_link.update!(sync_status: :syncing)

    # 1. Sync accounts (creates/updates BankAccount records + balances)
    accounts_result = BelvoSync::AccountsFetcher.call(belvo_link: belvo_link)
    unless accounts_result.success?
      belvo_link.update!(sync_status: :error, sync_error_message: "Account sync failed")
      return
    end

    # 2. Sync transactions for each connected account
    belvo_link.bank_accounts.where.not(belvo_account_id: nil).each do |account|
      BelvoSync::TransactionsFetcher.call(
        bank_account: account,
        date_from: date_from&.to_date,
        date_to: date_to&.to_date
      )
    end

    belvo_link.update!(sync_status: :synced, last_synced_at: Time.current, sync_error_message: nil)
  rescue StandardError => e
    belvo_link&.update(sync_status: :error, sync_error_message: e.message)
    raise
  end
end
