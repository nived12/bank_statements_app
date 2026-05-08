class MakeLegalConsentsUserIdNullable < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :legal_consents, :users
    change_column_null :legal_consents, :user_id, true
    add_foreign_key :legal_consents, :users, on_delete: :nullify
  end

  def down
    remove_foreign_key :legal_consents, :users
    change_column_null :legal_consents, :user_id, false
    add_foreign_key :legal_consents, :users
  end
end
