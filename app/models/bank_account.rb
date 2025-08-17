class BankAccount < ApplicationRecord
  belongs_to :user
  belongs_to :bank
  has_many :statement_files, dependent: :destroy
  has_many :transactions, through: :statement_files

  validates :bank, :account_number, presence: true
  validates :custom_name, length: { maximum: 100 }

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
