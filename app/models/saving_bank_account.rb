# frozen_string_literal: true

##
# SavingBankAccount
# Junction model representing the many-to-many relationship between Savings and BankAccounts
# Allows a saving to track multiple bank accounts for auto-sync functionality
#
class SavingBankAccount < ApplicationRecord
  belongs_to :saving
  belongs_to :bank_account

  validates :saving_id, uniqueness: { scope: :bank_account_id, message: "Bank account already added to this saving" }
  validates :bank_account_id, presence: true
  validates :saving_id, presence: true
end

# == Schema Information
#
# Table name: saving_bank_accounts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  saving_id            :integer         not null   no default           index: index_saving_bank_accounts_on_saving_id, index_saving_bank_accounts_on_saving_id_and_bank_account_id
#  bank_account_id      :integer         not null   no default           index: index_saving_bank_accounts_on_bank_account_id, index_saving_bank_accounts_on_saving_id_and_bank_account_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_saving_bank_accounts_on_bank_account_id (bank_account_id) non-unique
#  index_saving_bank_accounts_on_saving_id (saving_id) non-unique
#  index_saving_bank_accounts_on_saving_id_and_bank_account_id (saving_id, bank_account_id) unique
#
