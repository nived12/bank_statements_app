class AddContributionTrackingToSavings < ActiveRecord::Migration[8.0]
  def change
    add_column :savings, :target_contribution_amount, :decimal, precision: 12, scale: 2
    add_column :savings, :contribution_frequency, :string, default: "monthly"
    add_column :savings, :contribution_mode, :string, default: "none"
  end
end
