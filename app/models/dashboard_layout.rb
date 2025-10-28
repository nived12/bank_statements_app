class DashboardLayout < ApplicationRecord
  belongs_to :user

  # Default widget configuration
  DEFAULT_WIDGETS = [
    { "id" => "financial_health", "enabled" => true, "position" => 0, "size" => "full" },
    { "id" => "income_expenses", "enabled" => true, "position" => 1, "size" => "full" },
    { "id" => "category_breakdown", "enabled" => true, "position" => 2, "size" => "full" },
    { "id" => "cash_flow_timeline", "enabled" => false, "position" => 3, "size" => "full" },
    { "id" => "account_balances", "enabled" => false, "position" => 4, "size" => "half" },
    { "id" => "recent_transactions", "enabled" => true, "position" => 5, "size" => "full" }
  ].freeze

  validates :user_id, uniqueness: true

  def widgets
    widget_config["widgets"] || DEFAULT_WIDGETS.dup
  end

  def enabled_widgets
    widgets.select { |w| w["enabled"] }.sort_by { |w| w["position"] }
  end

  def update_widgets!(new_widgets)
    # Ensure at least 3 widgets are enabled
    enabled_count = new_widgets.count { |w| w["enabled"] }
    raise ArgumentError, "At least 3 widgets must be enabled" if enabled_count < 3

    update!(widget_config: { "widgets" => new_widgets })
  end
end
