class SavingTransaction < ApplicationRecord
  # Associations
  belongs_to :saving
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id"

  # Validations
  validates :saving_id, presence: true
  validates :transaction_id, presence: true
  validates :amount_applied, presence: true, numericality: { other_than: 0 }

  # Ensure unique saving-transaction pair
  validates :transaction_id, uniqueness: { scope: :saving_id, message: "is already linked to this saving" }

  validate :transaction_after_opening_balance_date, on: :create

  # Callbacks
  after_save :update_saving_current_amount
  after_destroy :update_saving_current_amount

  private

  # Update the saving's current_amount after linking/unlinking transactions
  def update_saving_current_amount
    return unless saving.present?
    # Recalculate if amount changed or if we're destroying the record
    return unless destroyed? || saved_change_to_amount_applied?

    saving.recalculate_current_amount!
  end

  def transaction_after_opening_balance_date
    return if saving.blank? || transaction_record.blank? || transaction_record.date.blank?
    return if transaction_record.date > saving.opening_balance_date

    errors.add(
      :transaction_id, I18n.t(
        "savings.errors.transaction_before_opening_balance",
        transaction_date: I18n.l(transaction_record.date, format: :long),
        opening_balance_date: I18n.l(saving.opening_balance_date, format: :long)
      )
    )
  end
end

# == Schema Information
#
# Table name: saving_transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  saving_id            :integer         not null   no default           index: index_saving_transactions_on_saving_id, index_saving_transactions_on_saving_id_and_transaction_id
#  transaction_id       :integer         not null   no default           index: index_saving_transactions_on_saving_id_and_transaction_id, index_saving_transactions_on_transaction_id
#  amount_applied       :decimal         not null   no default           no index
#  notes                :text            null       no default           no index
#  manual               :boolean         not null   default: true        no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_saving_transactions_on_saving_id (saving_id) non-unique
#  index_saving_transactions_on_saving_id_and_transaction_id (saving_id, transaction_id) unique
#  index_saving_transactions_on_transaction_id (transaction_id) non-unique
#
