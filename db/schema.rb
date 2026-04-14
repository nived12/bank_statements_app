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

ActiveRecord::Schema[8.0].define(version: 2026_04_11_033426) do
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
    t.bigint "bank_id"
    t.string "custom_name", limit: 100
    t.date "opening_balance_date", default: -> { "CURRENT_DATE" }, null: false
    t.string "account_type", default: "debit", null: false
    t.bigint "belvo_link_id"
    t.string "belvo_account_id"
    t.datetime "last_synced_at"
    t.string "sync_status"
    t.index ["account_type"], name: "index_bank_accounts_on_account_type"
    t.index ["bank_id"], name: "index_bank_accounts_on_bank_id"
    t.index ["belvo_account_id"], name: "index_bank_accounts_on_belvo_account_id", unique: true, where: "(belvo_account_id IS NOT NULL)"
    t.index ["belvo_link_id"], name: "index_bank_accounts_on_belvo_link_id"
    t.index ["opening_balance_date"], name: "index_bank_accounts_on_opening_balance_date"
    t.index ["user_id", "bank_id", "account_number"], name: "index_bank_accounts_on_user_bank_account_number_unique", unique: true, where: "((account_type)::text <> 'cash'::text)"
    t.index ["user_id"], name: "index_bank_accounts_on_user_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "supported_type"
    t.string "logo_url"
    t.index ["code"], name: "index_banks_on_code", unique: true
  end

  create_table "belvo_links", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "bank_id"
    t.string "belvo_link_id", null: false
    t.string "belvo_institution", null: false
    t.string "status", default: "active", null: false
    t.string "access_mode", default: "recurrent", null: false
    t.datetime "last_synced_at"
    t.string "sync_status", default: "pending"
    t.text "sync_error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_belvo_links_on_bank_id"
    t.index ["belvo_link_id"], name: "index_belvo_links_on_belvo_link_id", unique: true
    t.index ["status"], name: "index_belvo_links_on_status"
    t.index ["sync_status"], name: "index_belvo_links_on_sync_status"
    t.index ["user_id", "belvo_institution"], name: "index_belvo_links_on_user_id_and_belvo_institution", unique: true
    t.index ["user_id"], name: "index_belvo_links_on_user_id"
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

  create_table "category_rules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.string "match_type", default: "contains", null: false
    t.string "pattern", null: false
    t.integer "priority", default: 0, null: false
    t.integer "hits_count", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_rules_on_category_id"
    t.index ["user_id", "active"], name: "idx_category_rules_user_active"
    t.index ["user_id", "pattern", "match_type"], name: "idx_category_rules_user_pattern_match", unique: true
    t.index ["user_id"], name: "index_category_rules_on_user_id"
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
    t.string "payment_mode"
    t.decimal "target_payment_amount", precision: 12, scale: 2
    t.date "target_payoff_date"
    t.index ["due_day_of_month"], name: "index_debts_on_due_day_of_month"
    t.index ["target_payoff_date"], name: "index_debts_on_target_payoff_date"
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

  create_table "pay_charges", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "subscription_id"
    t.string "processor_id", null: false
    t.integer "amount", null: false
    t.string "currency"
    t.integer "application_fee_amount"
    t.integer "amount_refunded"
    t.jsonb "metadata"
    t.jsonb "data"
    t.string "stripe_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.jsonb "object"
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
    t.index ["subscription_id"], name: "index_pay_charges_on_subscription_id"
  end

  create_table "pay_customers", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default"
    t.jsonb "data"
    t.string "stripe_account"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.jsonb "object"
    t.index ["owner_type", "owner_id", "deleted_at"], name: "pay_customer_owner_index", unique: true
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id", unique: true
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "processor_id", null: false
    t.boolean "default"
    t.string "payment_method_type"
    t.jsonb "data"
    t.string "stripe_account"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "name", null: false
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", null: false
    t.datetime "current_period_start", precision: nil
    t.datetime "current_period_end", precision: nil
    t.datetime "trial_ends_at", precision: nil
    t.datetime "ends_at", precision: nil
    t.boolean "metered"
    t.string "pause_behavior"
    t.datetime "pause_starts_at", precision: nil
    t.datetime "pause_resumes_at", precision: nil
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.jsonb "metadata"
    t.jsonb "data"
    t.string "stripe_account"
    t.string "payment_method_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.jsonb "object"
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.string "processor"
    t.string "event_type"
    t.jsonb "event"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "concept"
    t.index ["bank_account_id"], name: "index_pending_transactions_on_bank_account_id"
    t.index ["concept"], name: "index_pending_transactions_on_concept"
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
    t.date "target_date"
    t.index ["target_date"], name: "index_savings_on_target_date"
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
    t.integer "status", default: 0, null: false
    t.datetime "cutoff_date"
    t.jsonb "usage_metadata", default: {}
    t.string "processing_strategy", default: "parser_only", null: false
    t.text "file_password"
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
    t.string "concept"
    t.string "belvo_transaction_id"
    t.index ["bank_account_id"], name: "index_transactions_on_bank_account_id"
    t.index ["belvo_transaction_id"], name: "index_transactions_on_belvo_transaction_id", unique: true, where: "(belvo_transaction_id IS NOT NULL)"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["concept"], name: "index_transactions_on_concept"
    t.index ["linked_transfer_id"], name: "index_transactions_on_linked_transfer_id"
    t.index ["source"], name: "index_transactions_on_source"
    t.index ["statement_file_id"], name: "index_transactions_on_statement_file_id"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "transfer_candidates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "outgoing_transaction_id", null: false
    t.bigint "incoming_transaction_id", null: false
    t.string "status", default: "pending", null: false
    t.decimal "similarity_score", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incoming_transaction_id"], name: "index_transfer_candidates_on_incoming_transaction_id"
    t.index ["outgoing_transaction_id", "incoming_transaction_id"], name: "idx_transfer_candidates_pair", unique: true
    t.index ["outgoing_transaction_id"], name: "index_transfer_candidates_on_outgoing_transaction_id"
    t.index ["user_id", "status"], name: "index_transfer_candidates_on_user_id_and_status"
    t.index ["user_id"], name: "index_transfer_candidates_on_user_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.jsonb "preferences", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
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
    t.datetime "confirmed_at"
    t.string "jti"
    t.datetime "refresh_token_expires_at"
    t.datetime "trial_ends_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bank_accounts", "banks"
  add_foreign_key "bank_accounts", "belvo_links"
  add_foreign_key "bank_accounts", "users"
  add_foreign_key "belvo_links", "banks"
  add_foreign_key "belvo_links", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "users"
  add_foreign_key "category_rules", "categories"
  add_foreign_key "category_rules", "users"
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
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_charges", "pay_subscriptions", column: "subscription_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
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
  add_foreign_key "transfer_candidates", "transactions", column: "incoming_transaction_id"
  add_foreign_key "transfer_candidates", "transactions", column: "outgoing_transaction_id"
  add_foreign_key "transfer_candidates", "users"
  add_foreign_key "user_settings", "users"
end
