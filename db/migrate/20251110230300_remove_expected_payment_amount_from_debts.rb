class RemoveExpectedPaymentAmountFromDebts < ActiveRecord::Migration[8.0]
  def change
    remove_column :debts, :expected_payment_amount, :decimal, precision: 12, scale: 2
  end
end
