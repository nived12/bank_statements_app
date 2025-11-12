class AddPaymentTrackingToDebts < ActiveRecord::Migration[8.0]
  def change
    add_column :debts, :due_day_of_month, :integer
    add_column :debts, :payment_frequency, :string, default: "monthly"
    add_column :debts, :expected_payment_amount, :decimal, precision: 12, scale: 2

    add_index :debts, :due_day_of_month
  end
end
