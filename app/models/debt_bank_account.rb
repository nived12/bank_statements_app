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
