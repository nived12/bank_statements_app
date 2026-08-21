class AddOpeningBalanceToSavingsAndDebts < ActiveRecord::Migration[8.0]
  def up
    # No DB-level default on opening_balance, matching bank_accounts.opening_balance. A
    # literal default (unlike opening_balance_date's CURRENT_DATE) gets reflected in Rails'
    # in-memory attributes on .new, which would make `self.opening_balance ||= original_amount`
    # in Debt#set_defaults silently never fire. Presence is enforced at the model level instead.
    add_column :savings, :opening_balance, :decimal, precision: 12, scale: 2
    add_column :savings, :opening_balance_date, :date
    add_column :debts, :opening_balance, :decimal, precision: 12, scale: 2
    add_column :debts, :opening_balance_date, :date

    # Anchor at created_at so no existing balance moves. Reverse-solved rather than
    # assumed zero: a link dated on/before created_at (matched by category+account
    # before the record even existed) must stay inside the anchor, not get double
    # counted once the date filter goes live.
    execute <<~SQL.squish
      UPDATE savings s SET
        opening_balance_date = s.created_at::date,
        opening_balance = s.current_amount - COALESCE((
          SELECT SUM(st.amount_applied) FROM saving_transactions st
          JOIN transactions t ON t.id = st.transaction_id
          WHERE st.saving_id = s.id AND t.date > s.created_at::date), 0)
    SQL

    execute <<~SQL.squish
      UPDATE debts d SET
        opening_balance_date = d.created_at::date,
        opening_balance = d.current_balance + COALESCE((
          SELECT SUM(dt.amount_applied) FROM debt_transactions dt
          JOIN transactions t ON t.id = dt.transaction_id
          WHERE dt.debt_id = d.id AND t.date > d.created_at::date), 0)
    SQL

    change_column_null :savings, :opening_balance_date, false
    change_column_default :savings, :opening_balance_date, -> { "CURRENT_DATE" }
    change_column_null :debts, :opening_balance_date, false
    change_column_default :debts, :opening_balance_date, -> { "CURRENT_DATE" }

    # savings.opening_balance's desired default (0) is static, so a DB default is safe and
    # harmless alongside Saving#set_defaults' own `||= 0`. debts.opening_balance gets no DB
    # default — its desired default (original_amount) isn't static, and a default here would
    # silently defeat Debt#default_amounts, for the same reason explained above. Both are
    # NOT NULL: Debt#default_amounts always populates it before validation on create, and
    # the model's presence validation blocks nulling it on update.
    change_column_null :savings, :opening_balance, false
    change_column_default :savings, :opening_balance, 0
    change_column_null :debts, :opening_balance, false

    # Both auto-linkers filter on opening_balance_date on every transaction save, so this
    # is a hot read path — matching the index bank_accounts.opening_balance_date carries.
    add_index :savings, :opening_balance_date
    add_index :debts, :opening_balance_date
  end

  def down
    # Dropping the columns drops their indexes with them.
    remove_column :savings, :opening_balance
    remove_column :savings, :opening_balance_date
    remove_column :debts, :opening_balance
    remove_column :debts, :opening_balance_date
  end
end
