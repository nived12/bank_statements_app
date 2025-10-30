# frozen_string_literal: true

##
# DebtBankAccount
# Junction model representing the many-to-many relationship between Debts and BankAccounts
# Allows a debt to track multiple bank accounts for auto-sync functionality
#
class DebtBankAccount < ApplicationRecord
  belongs_to :debt
  belongs_to :bank_account

  validates :debt_id, uniqueness: { scope: :bank_account_id, message: "Bank account already added to this debt" }
  validates :bank_account_id, presence: true
  validates :debt_id, presence: true
end

# == Schema Information
#
# Table name: debt_bank_accounts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  debt_id              :integer         not null   no default           index: index_debt_bank_accounts_on_debt_id, index_debt_bank_accounts_on_debt_id_and_bank_account_id
#  bank_account_id      :integer         not null   no default           index: index_debt_bank_accounts_on_bank_account_id, index_debt_bank_accounts_on_debt_id_and_bank_account_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_debt_bank_accounts_on_bank_account_id (bank_account_id) non-unique
#  index_debt_bank_accounts_on_debt_id (debt_id) non-unique
#  index_debt_bank_accounts_on_debt_id_and_bank_account_id (debt_id, bank_account_id) unique
#
