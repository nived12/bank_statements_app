class AddInternalAccountToUsers < ActiveRecord::Migration[8.0]
  # Accounts that exist for store review, demos or testing. They are real rows
  # with real data, so nothing else distinguishes them from customers. A
  # broadcast that reaches the App Review fixture is both embarrassing and a
  # rejection risk, since that account has to stay in its expired state.
  INTERNAL_EMAILS = %w[demo-expired@vitt.io].freeze

  def up
    add_column :users, :internal_account, :boolean, default: false, null: false
    User.where(email: INTERNAL_EMAILS).update_all(internal_account: true)
  end

  def down
    remove_column :users, :internal_account
  end
end
