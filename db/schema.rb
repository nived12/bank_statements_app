# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_05_151032) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.string "account_number"
    t.string "currency"
    t.decimal "opening_balance", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "bank_id", null: false
    t.string "custom_name", limit: 100
    t.date "opening_balance_date", default: -> { "CURRENT_DATE" }, null: false
    t.integer "account_type", default: 0, null: false
    t.index ["account_type"], name: "index_bank_accounts_on_account_type"
    t.index ["bank_id"], name: "index_bank_accounts_on_bank_id"
    t.index ["opening_balance_date"], name: "index_bank_accounts_on_opening_balance_date"
    t.index ["user_id"], name: "index_bank_accounts_on_user_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "supported_type"
    t.index ["code"], name: "index_banks_on_code", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "user_id"
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["user_id", "parent_id", "name"], name: "idx_categories_user_parent_name", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "dashboard_layouts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.jsonb "widget_config", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_dashboard_layouts_on_user_id", unique: true
  end

  create_table "debt_bank_accounts", force: :cascade do |t|
    t.bigint "debt_id", null: false
    t.bigint "bank_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_account_id"], name: "index_debt_bank_accounts_on_bank_account_id"
    t.index ["debt_id", "bank_account_id"], name: "index_debt_bank_accounts_on_debt_id_and_bank_account_id", unique: true
    t.index ["debt_id"], name: "index_debt_bank_accounts_on_debt_id"
  end

  create_table "debt_categories", force: :cascade do |t|
    t.bigint "debt_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_debt_categories_on_category_id"
    t.index ["debt_id", "category_id"], name: "index_debt_categories_on_debt_id_and_category_id", unique: true
    t.index ["debt_id"], name: "index_debt_categories_on_debt_id"
  end

  create_table "debt_transactions", force: :cascade do |t|
    t.bigint "debt_id", null: false
    t.bigint "transaction_id", null: false
    t.decimal "amount_applied", precision: 12, scale: 2, null: false
    t.text "notes"
    t.boolean "manual", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["debt_id", "transaction_id"], name: "index_debt_transactions_on_debt_id_and_transaction_id", unique: true
    t.index ["debt_id"], name: "index_debt_transactions_on_debt_id"
    t.index ["transaction_id"], name: "index_debt_transactions_on_transaction_id"
  end

  create_table "debts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "original_amount", precision: 12, scale: 2
    t.decimal "current_balance", precision: 12, scale: 2, null: false
    t.decimal "interest_rate", precision: 5, scale: 2
    t.decimal "minimum_payment", precision: 12, scale: 2
    t.jsonb "calculation_settings", default: {}, null: false
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "icon"
    t.string "color", default: "#EF4444"
    t.boolean "auto_sync_transactions", default: false, null: false
    t.integer "due_day_of_month"
    t.string "payment_frequency", default: "monthly"
    t.decimal "expected_payment_amount", precision: 12, scale: 2
    t.index ["due_day_of_month"], name: "index_debts_on_due_day_of_month"
    t.index ["user_id"], name: "index_debts_on_user_id"
  end

  create_table "goal_debts", force: :cascade do |t|
    t.bigint "goal_id", null: false
    t.bigint "debt_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["debt_id"], name: "index_goal_debts_on_debt_id"
    t.index ["goal_id"], name: "index_goal_debts_on_goal_id"
  end

  create_table "goal_savings", force: :cascade do |t|
    t.bigint "goal_id", null: false
    t.bigint "saving_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_goal_savings_on_goal_id"
    t.index ["saving_id"], name: "index_goal_savings_on_saving_id"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "goal_type", null: false
    t.date "start_date", null: false
    t.date "deadline", null: false
    t.string "debt_strategy"
    t.string "icon"
    t.string "color", default: "#3B82F6", null: false
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.jsonb "goal_calculation_settings", default: {}, null: false
    t.index ["deadline"], name: "index_goals_on_deadline"
    t.index ["discarded_at"], name: "index_goals_on_discarded_at"
    t.index ["goal_type"], name: "index_goals_on_goal_type"
    t.index ["status"], name: "index_goals_on_status"
    t.index ["user_id", "status"], name: "index_goals_on_user_id_and_status"
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "pending_transactions", force: :cascade do |t|
    t.bigint "statement_file_id", null: false
    t.bigint "user_id", null: false
    t.bigint "bank_account_id", null: false
    t.text "description"
    t.decimal "amount"
    t.string "transaction_type"
    t.string "merchant"
    t.string "reference"
    t.integer "category_id"
    t.decimal "confidence"
    t.decimal "category_confidence"
    t.decimal "transaction_type_confidence"
    t.integer "source", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date"
    t.index ["bank_account_id"], name: "index_pending_transactions_on_bank_account_id"
    t.index ["source"], name: "index_pending_transactions_on_source"
    t.index ["statement_file_id"], name: "index_pending_transactions_on_statement_file_id"
    t.index ["user_id"], name: "index_pending_transactions_on_user_id"
  end

  create_table "saving_bank_accounts", force: :cascade do |t|
    t.bigint "saving_id", null: false
    t.bigint "bank_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_account_id"], name: "index_saving_bank_accounts_on_bank_account_id"
    t.index ["saving_id", "bank_account_id"], name: "index_saving_bank_accounts_on_saving_id_and_bank_account_id", unique: true
    t.index ["saving_id"], name: "index_saving_bank_accounts_on_saving_id"
  end

  create_table "saving_categories", force: :cascade do |t|
    t.bigint "saving_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_saving_categories_on_category_id"
    t.index ["saving_id", "category_id"], name: "index_saving_categories_on_saving_id_and_category_id", unique: true
    t.index ["saving_id"], name: "index_saving_categories_on_saving_id"
  end

  create_table "saving_transactions", force: :cascade do |t|
    t.bigint "saving_id", null: false
    t.bigint "transaction_id", null: false
    t.decimal "amount_applied", precision: 12, scale: 2, null: false
    t.text "notes"
    t.boolean "manual", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["saving_id", "transaction_id"], name: "index_saving_transactions_on_saving_id_and_transaction_id", unique: true
    t.index ["saving_id"], name: "index_saving_transactions_on_saving_id"
    t.index ["transaction_id"], name: "index_saving_transactions_on_transaction_id"
  end

  create_table "savings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "target_amount", precision: 12, scale: 2, null: false
    t.decimal "current_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.jsonb "calculation_settings", default: {}, null: false
    t.string "icon"
    t.string "color", default: "#3B82F6"
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "auto_sync_transactions", default: false, null: false
    t.decimal "target_contribution_amount", precision: 12, scale: 2
    t.string "contribution_frequency", default: "monthly"
    t.string "contribution_mode"
    t.index ["user_id"], name: "index_savings_on_user_id"
  end

  create_table "statement_files", force: :cascade do |t|
    t.bigint "bank_account_id", null: false
    t.datetime "processed_at"
    t.jsonb "parsed_json", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error_message"
    t.bigint "user_id", null: false
    t.jsonb "redaction_map", default: {}
    t.string "redaction_hmac"
    t.boolean "ai_enabled", default: true, null: false
    t.integer "status", default: 0, null: false
    t.datetime "cutoff_date"
    t.index ["bank_account_id"], name: "index_statement_files_on_bank_account_id"
    t.index ["cutoff_date"], name: "index_statement_files_on_cutoff_date"
    t.index ["redaction_hmac"], name: "index_statement_files_on_redaction_hmac"
    t.index ["user_id"], name: "index_statement_files_on_user_id"
  end

  create_table "statement_financial_summaries", force: :cascade do |t|
    t.bigint "statement_file_id", null: false
    t.string "statement_type", null: false
    t.decimal "initial_balance", precision: 12, scale: 2
    t.decimal "final_balance", precision: 12, scale: 2
    t.date "statement_period_start"
    t.date "statement_period_end"
    t.integer "days_in_period"
    t.decimal "total_commissions", precision: 12, scale: 2
    t.decimal "total_fees", precision: 12, scale: 2
    t.json "statement_type_data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["statement_file_id"], name: "index_statement_financial_summaries_on_statement_file_id"
    t.index ["statement_type", "statement_period_start"], name: "idx_on_statement_type_statement_period_start_8809139a5b"
    t.index ["statement_type"], name: "index_statement_financial_summaries_on_statement_type"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "bank_account_id", null: false
    t.bigint "statement_file_id"
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "transaction_type", null: false
    t.string "merchant"
    t.string "reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "category_id"
    t.decimal "confidence", precision: 3, scale: 2
    t.decimal "category_confidence", precision: 3, scale: 2
    t.decimal "transaction_type_confidence", precision: 3, scale: 2
    t.integer "source", default: 0, null: false
    t.bigint "linked_transfer_id"
    t.date "date"
    t.index ["bank_account_id"], name: "index_transactions_on_bank_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["linked_transfer_id"], name: "index_transactions_on_linked_transfer_id"
    t.index ["source"], name: "index_transactions_on_source"
    t.index ["statement_file_id"], name: "index_transactions_on_statement_file_id"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "avatar_url"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bank_accounts", "banks"
  add_foreign_key "bank_accounts", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "users"
  add_foreign_key "debt_bank_accounts", "bank_accounts"
  add_foreign_key "debt_bank_accounts", "debts"
  add_foreign_key "debt_categories", "categories"
  add_foreign_key "debt_categories", "debts"
  add_foreign_key "debt_transactions", "debts"
  add_foreign_key "debt_transactions", "transactions"
  add_foreign_key "debts", "users"
  add_foreign_key "goal_debts", "debts"
  add_foreign_key "goal_debts", "goals"
  add_foreign_key "goal_savings", "goals"
  add_foreign_key "goal_savings", "savings"
  add_foreign_key "goals", "users"
  add_foreign_key "pending_transactions", "bank_accounts"
  add_foreign_key "pending_transactions", "statement_files"
  add_foreign_key "pending_transactions", "users"
  add_foreign_key "saving_bank_accounts", "bank_accounts"
  add_foreign_key "saving_bank_accounts", "savings"
  add_foreign_key "saving_categories", "categories"
  add_foreign_key "saving_categories", "savings"
  add_foreign_key "saving_transactions", "savings"
  add_foreign_key "saving_transactions", "transactions"
  add_foreign_key "savings", "users"
  add_foreign_key "statement_files", "bank_accounts"
  add_foreign_key "statement_files", "users"
  add_foreign_key "statement_financial_summaries", "statement_files", on_delete: :cascade
  add_foreign_key "transactions", "bank_accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "statement_files"
  add_foreign_key "transactions", "transactions", column: "linked_transfer_id"
  add_foreign_key "transactions", "users"
end
