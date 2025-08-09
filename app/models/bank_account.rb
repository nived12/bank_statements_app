class BankAccount < ApplicationRecord
  has_many :statement_files, dependent: :destroy

  validates :bank_name, :account_number, presence: true

  def display_name
    "#{bank_name} • #{account_number}"
  end
end
