class CreateDashboardLayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :dashboard_layouts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :widget_config, default: {}, null: false
      t.timestamps
    end
  end
end
