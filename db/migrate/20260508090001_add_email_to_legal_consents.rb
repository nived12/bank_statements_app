class AddEmailToLegalConsents < ActiveRecord::Migration[8.0]
  def up
    add_column :legal_consents, :email, :string

    # Backfill existing records from the associated user
    execute <<~SQL
      UPDATE legal_consents
      SET email = users.email
      FROM users
      WHERE legal_consents.user_id = users.id
    SQL

    change_column_null :legal_consents, :email, false
  end

  def down
    remove_column :legal_consents, :email
  end
end
