class BelvoSync::AccountsFetcher < ApplicationService
  def initialize(belvo_link:)
    super()
    @belvo_link = belvo_link
  end

  def call
    client_result = Belvo::ClientFactory.call
    return failure("Belvo client error") unless client_result.success?

    client = client_result.payload
    accounts = client.accounts.retrieve(link: @belvo_link.belvo_link_id)
    accounts = Array.wrap(accounts)

    accounts.each do |belvo_account|
      find_or_create_bank_account(belvo_account)
    end

    success(accounts.size)
  rescue ::Belvo::RequestError => e
    failure("Account sync failed: #{e.message}")
  end

  private

  def find_or_create_bank_account(belvo_account)
    account_id = belvo_account["id"]
    existing = BankAccount.find_by(belvo_account_id: account_id)

    if existing
      update_existing(existing, belvo_account)
    else
      create_new_account(belvo_account)
    end
  end

  def create_new_account(belvo_account)
    BankAccount.create!(
      user: @belvo_link.user,
      bank: @belvo_link.bank,
      belvo_link: @belvo_link,
      belvo_account_id: belvo_account["id"],
      account_number: belvo_account["number"] || belvo_account["internal_identification"] || belvo_account["id"],
      custom_name: belvo_account["name"],
      currency: belvo_account["currency"] || "MXN",
      account_type: map_account_type(belvo_account["type"]),
      opening_balance: extract_balance(belvo_account),
      opening_balance_date: Date.current,
      last_synced_at: Time.current,
      sync_status: "synced"
    )
  end

  def update_existing(account, belvo_account)
    balance = extract_balance(belvo_account)
    account.update!(
      opening_balance: balance,
      opening_balance_date: Date.current,
      last_synced_at: Time.current,
      sync_status: "synced"
    )
  end

  def map_account_type(belvo_type)
    case belvo_type.to_s.downcase
    when "credit", "credit_card", "creditcard"
      "credit"
    else
      "debit"
    end
  end

  def extract_balance(belvo_account)
    belvo_account.dig("balance", "current") ||
      belvo_account.dig("balance", "available") ||
      0
  end
end
