class BankAccount < ApplicationRecord
  belongs_to :user
  has_many :statement_files, dependent: :destroy
  has_many :transactions, through: :statement_files

  validates :bank_name, :account_number, presence: true

  def display_name
    "#{bank_name} • #{account_number}"
  end
end

# == Schema Information
#
# Table name: bank_accounts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_name            :string          null       no default           no index
#  account_number       :string          null       no default           no index
#  currency             :string          null       no default           no index
#  opening_balance      :decimal         null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  user_id              :integer         not null   no default           index: index_bank_accounts_on_user_id
#
# Indexes:
#  index_bank_accounts_on_user_id (user_id) non-unique
#
