class BankAccount < ApplicationRecord
  belongs_to :user
  belongs_to :bank
  has_many :statement_files, dependent: :destroy
  has_many :transactions, through: :statement_files

  validates :bank_id, :account_number, presence: { message: :required }
  validates :custom_name, length: { maximum: 100 }
  validates :opening_balance_date, presence: { message: :required }
  validate :opening_balance_date_cannot_be_in_future

  # Allow custom_name to be blank (will use bank.name)
  validates :custom_name, presence: false

  def display_name
    # Only use custom_name if it's actually different from both bank.name and bank.code
    # and if it's not just a short bank code (like "BBVA" vs "BBVA Bancomer")
    if custom_name.present? &&
       custom_name != bank.name &&
       custom_name != bank.code &&
       !bank.name.downcase.include?(custom_name.downcase)
      "#{custom_name} • #{account_number}"
    else
      "#{bank.name} • #{account_number}"
    end
  end

  def bank_name
    bank.code
  end

  def bank_display_name
    bank.name
  end

  def supported_for_parsing?
    bank&.supported_for_parsing?
  end

  def parser_type
    return "generic" unless supported_for_parsing?

    # Special handling for BBVA to detect credit card vs savings
    if bank.code == "bbva"
      "bbva" # The parser will auto-detect credit card vs savings
    else
      bank.code
    end
  end

  # Calculate effective balance from opening balance date forward
  def effective_balance(as_of_date = Date.current)
    return opening_balance if as_of_date < opening_balance_date

    # Use the optimized scope for better performance
    relevant_transactions.sum(:amount)
                        .then { |transaction_sum| opening_balance + transaction_sum }
  end

  # Get transactions that should be included in balance calculations
  def relevant_transactions
    transactions.relevant_for_balance(opening_balance_date)
  end

  # Get transactions that are before opening balance date (for reference only)
  def historical_transactions
    transactions.historical(opening_balance_date)
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
#  account_number       :string          null       no default           no index
#  currency             :string          null       no default           no index
#  opening_balance      :decimal         null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  user_id              :integer         not null   no default           index: index_bank_accounts_on_user_id
#  bank_id              :integer         not null   no default           index: index_bank_accounts_on_bank_id
#  custom_name          :string          null       no default           no index
#
# Indexes:
#  index_bank_accounts_on_bank_id (bank_id) non-unique
#  index_bank_accounts_on_user_id (user_id) non-unique
#
