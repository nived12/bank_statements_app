class DebtTransaction < ApplicationRecord
  # Associations
  belongs_to :debt
  belongs_to :transaction_record, class_name: "Transaction"

  # Validations
  validates :debt_id, presence: true
  validates :transaction_id, presence: true
  validates :amount_applied, presence: true, numericality: { other_than: 0 }

  # Ensure unique debt-transaction pair
  validates :transaction_id, uniqueness: { scope: :debt_id, message: "is already linked to this debt" }

  # Callbacks
  after_save :update_debt_current_balance
  after_destroy :update_debt_current_balance

  private

  # Update the debt's current_balance after linking/unlinking transactions
  def update_debt_current_balance
    debt.recalculate_current_balance! if debt.present?
  end
end

# == Schema Information
#
# Table name: debt_transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  debt_id              :integer         not null   no default           index: index_debt_transactions_on_debt_id, index_debt_transactions_on_debt_id_and_transaction_id
#  transaction_id       :integer         not null   no default           index: index_debt_transactions_on_debt_id_and_transaction_id, index_debt_transactions_on_transaction_id
#  amount_applied       :decimal         not null   no default           no index
#  notes                :text            null       no default           no index
#  manual               :boolean         not null   default: true        no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_debt_transactions_on_debt_id (debt_id) non-unique
#  index_debt_transactions_on_debt_id_and_transaction_id (debt_id, transaction_id) unique
#  index_debt_transactions_on_transaction_id (transaction_id) non-unique
#
