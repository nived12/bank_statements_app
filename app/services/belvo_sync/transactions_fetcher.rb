class BelvoSync::TransactionsFetcher < ApplicationService
  include Transactions::Concerns::ConceptSimilarity

  def initialize(bank_account:, date_from: nil, date_to: nil)
    super()
    @bank_account = bank_account
    @belvo_link = bank_account.belvo_link
    @date_from = date_from || 30.days.ago.to_date
    @date_to = date_to || Date.current
  end

  def call
    client_result = Belvo::ClientFactory.call
    return failure("Belvo client error") unless client_result.success?

    client = client_result.payload
    @bank_account.update!(sync_status: "syncing")

    belvo_transactions = client.transactions.retrieve(
      link: @belvo_link.belvo_link_id,
      date_from: @date_from.to_s,
      options: { date_to: @date_to.to_s, account: @bank_account.belvo_account_id }
    )
    belvo_transactions = Array.wrap(belvo_transactions)

    imported_count = 0
    belvo_transactions.each do |bt|
      next if already_imported?(bt["id"])

      normalized = BelvoSync::TransactionNormalizer.call(
        belvo_transaction: bt,
        bank_account: @bank_account
      )
      next unless normalized.success?

      # Cross-source duplicate check against existing manual/PDF transactions
      next if cross_source_duplicate?(normalized.payload)

      Transaction.create!(normalized.payload)
      imported_count += 1
    end

    @bank_account.update!(last_synced_at: Time.current, sync_status: "synced")
    success(imported_count: imported_count)
  rescue ::Belvo::RequestError => e
    @bank_account.update!(sync_status: "error")
    failure("Transaction sync failed: #{e.message}")
  rescue StandardError => e
    @bank_account.update!(sync_status: "error")
    failure("Transaction sync failed: #{e.message}")
  end

  private

  def already_imported?(belvo_transaction_id)
    Transaction.exists?(belvo_transaction_id: belvo_transaction_id)
  end

  def cross_source_duplicate?(attrs)
    candidates = Transaction.where(
      user: attrs[:user],
      bank_account: attrs[:bank_account],
      date: attrs[:date],
      amount: attrs[:amount]
    ).where.not(source: :bank_api)

    incoming = {
      "description" => attrs[:description].to_s,
      "concept" => attrs[:concept].to_s
    }

    candidates.any? { |existing| concept_similar_enough?(incoming, existing) }
  end
end
