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
