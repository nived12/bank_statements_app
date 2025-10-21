class AddInterestRateToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :interest_rate, :decimal, precision: 5, scale: 2, null: true
  end
end
