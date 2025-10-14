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

ActiveRecord::Schema[8.0].define(version: 2025_10_09_055629) do
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

  create_table "pending_transactions", force: :cascade do |t|
    t.bigint "statement_file_id", null: false
    t.bigint "user_id", null: false
    t.bigint "bank_account_id", null: false
    t.date "date"
    t.text "description"
    t.decimal "amount"
    t.string "transaction_type"
    t.string "bank_entry_type"
    t.string "merchant"
    t.string "reference"
    t.integer "category_id"
    t.decimal "confidence"
    t.decimal "category_confidence"
    t.decimal "transaction_type_confidence"
    t.integer "source", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_account_id"], name: "index_pending_transactions_on_bank_account_id"
    t.index ["source"], name: "index_pending_transactions_on_source"
    t.index ["statement_file_id"], name: "index_pending_transactions_on_statement_file_id"
    t.index ["user_id", "bank_account_id", "date", "amount"], name: "index_pending_transactions_on_duplicate_fields"
    t.index ["user_id"], name: "index_pending_transactions_on_user_id"
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
    t.index ["bank_account_id"], name: "index_statement_files_on_bank_account_id"
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
    t.date "date", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "transaction_type", null: false
    t.string "bank_entry_type"
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
    t.index ["bank_account_id", "date"], name: "index_transactions_on_bank_account_id_and_date"
    t.index ["bank_account_id"], name: "index_transactions_on_bank_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["date"], name: "index_transactions_on_date"
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
  add_foreign_key "pending_transactions", "bank_accounts"
  add_foreign_key "pending_transactions", "statement_files"
  add_foreign_key "pending_transactions", "users"
  add_foreign_key "statement_files", "bank_accounts"
  add_foreign_key "statement_files", "users"
  add_foreign_key "statement_financial_summaries", "statement_files", on_delete: :cascade
  add_foreign_key "transactions", "bank_accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "statement_files"
  add_foreign_key "transactions", "transactions", column: "linked_transfer_id"
  add_foreign_key "transactions", "users"
end
