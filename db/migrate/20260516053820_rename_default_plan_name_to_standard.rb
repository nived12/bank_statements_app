# frozen_string_literal: true

class RenameDefaultPlanNameToStandard < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE pay_subscriptions SET name = 'standard' WHERE name = 'default'"
  end

  def down
    execute "UPDATE pay_subscriptions SET name = 'default' WHERE name = 'standard'"
  end
end
