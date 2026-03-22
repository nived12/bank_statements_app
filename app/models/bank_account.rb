class BankAccount < ApplicationRecord
  belongs_to :user
  belongs_to :bank, optional: true
  has_many :statement_files, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :debt_bank_accounts, dependent: :destroy
  has_many :pending_transactions, dependent: :destroy
  has_many :saving_bank_accounts, dependent: :destroy

  enum :account_type, {
    debit: "debit",    # Default - regular bank accounts (checking/savings)
    credit: "credit",  # Credit card accounts
    cash: "cash"       # Cash accounts (no bank, no account number)
  }, default: "debit"

  validates :bank_id, :account_number, presence: { message: :required }, unless: :cash?
  validates :account_number, uniqueness: { scope: [:user_id, :bank_id], message: :taken }, unless: :cash?
  validates :custom_name, length: { maximum: 100 }
  validates :opening_balance_date, presence: { message: :required }
  validate :opening_balance_date_cannot_be_in_future

  # Allow custom_name to be blank (will use bank.name)
  validates :custom_name, presence: false

  def display_name
    if cash?
      custom_name.presence || I18n.t("account_type.cash")
    elsif custom_name.present? &&
       custom_name != bank.name &&
       custom_name != bank.code &&
       !bank.name.downcase.include?(custom_name.downcase)
      "#{custom_name} • #{account_number}"
    else
      "#{bank.name} • #{account_number}"
    end
  end

  def bank_name
    bank&.code
  end

  def bank_display_name
    cash? ? I18n.t("account_type.cash") : bank&.name
  end

  def supported_for_parsing?
    return false if cash?

    bank&.supported_for_parsing?
  end

  def support_indicator_text
    if supported_for_parsing?
      I18n.t("statement_upload.supported_by_vittio")
    else
      I18n.t("statement_upload.supported_by_ai")
    end
  end

  def parser_type
    return "generic" if cash?
    return "generic" unless supported_for_parsing?

    # Use account_type to determine parser for supported banks
    case bank.code
    when "bbva"
      account_type == "credit" ? "bbva_credit_card" : "bbva_savings"
    when "santander"
      account_type == "credit" ? "santander_credit_card" : "santander_savings"
    when "banorte"
      account_type == "credit" ? "banorte_credit_card" : "banorte_savings"
    when "scotiabank"
      account_type == "credit" ? "scotiabank_credit_card" : "scotiabank_savings"
    when "rappi"
      "rappi_credit_card"
    when "nu"
      "nu_savings"
    else
      bank.code
    end
  end

  def parser_class
    return nil if cash?

    # Check if bank supports this account type
    if bank.supports_account_type?(account_type)
      # Use specific parser based on parser_type
      case parser_type
      when "bbva_savings"
        PdfParser::BbvaSavingsAccount
      when "bbva_credit_card"
        PdfParser::BbvaCreditCard
      when "santander_savings"
        PdfParser::SantanderSavingsAccount
      when "santander_credit_card"
        PdfParser::Generic
      when "banorte_savings"
        PdfParser::BanorteSavingsAccount
      when "banorte_credit_card"
        PdfParser::Generic
      when "scotiabank_credit_card"
        PdfParser::ScotiabankCreditCard
      when "scotiabank_savings"
        PdfParser::Generic
      when "rappi_credit_card"
        PdfParser::RappiCreditCard
      when "nu_savings"
        PdfParser::NuSavingsAccount
      else
        PdfParser::Generic
      end
    else
      # Bank doesn't support this account type, use AI Post Processor
      Ai::PostProcessor
    end
  end

  # Calculate effective balance from opening balance date forward
  def effective_balance(as_of_date = Date.current)
    # Use the optimized scope for better performance
    opening_balance_amount = opening_balance || 0
    return opening_balance_amount if as_of_date < opening_balance_date

    transaction_sum = relevant_transactions.sum(:amount) || 0

    opening_balance_amount + transaction_sum
  end

  # Get transactions that should be included in balance calculations
  def relevant_transactions
    transactions.relevant_for_balance(opening_balance_date)
  end

  private

  def opening_balance_date_cannot_be_in_future
    if opening_balance_date.present? && opening_balance_date > Date.current
      errors.add(:opening_balance_date, "cannot be in the future")
    end
  end
end

# == Schema Information
#
# Table name: bank_accounts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  account_number       :string          null       no default           index: index_bank_accounts_on_user_bank_account_number_unique
#  currency             :string          null       no default           no index
#  opening_balance      :decimal         null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  user_id              :integer         not null   no default           index: index_bank_accounts_on_user_bank_account_number_unique, index_bank_accounts_on_user_id
#  bank_id              :integer         null       no default           index: index_bank_accounts_on_bank_id, index_bank_accounts_on_user_bank_account_number_unique
#  custom_name          :string          null       no default           no index
#  opening_balance_date :date            not null   no default           index: index_bank_accounts_on_opening_balance_date
#  account_type         :string          not null   default: debit       index: index_bank_accounts_on_account_type
#
# Indexes:
#  index_bank_accounts_on_account_type (account_type) non-unique
#  index_bank_accounts_on_bank_id (bank_id) non-unique
#  index_bank_accounts_on_opening_balance_date (opening_balance_date) non-unique
#  index_bank_accounts_on_user_bank_account_number_unique (user_id, bank_id, account_number) unique
#  index_bank_accounts_on_user_id (user_id) non-unique
#
