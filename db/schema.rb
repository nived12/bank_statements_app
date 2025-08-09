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

ActiveRecord::Schema[8.0].define(version: 2025_08_09_224431) do
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
    t.string "bank_name"
    t.string "account_number"
    t.string "currency"
    t.decimal "opening_balance", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "statement_files", force: :cascade do |t|
    t.bigint "bank_account_id", null: false
    t.string "status"
    t.datetime "processed_at"
    t.jsonb "parsed_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error_message"
    t.index ["bank_account_id"], name: "index_statement_files_on_bank_account_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "bank_account_id", null: false
    t.bigint "statement_file_id", null: false
    t.date "date", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "transaction_type", null: false
    t.string "bank_entry_type"
    t.string "merchant"
    t.string "reference"
    t.string "category"
    t.string "sub_category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_account_id"], name: "index_transactions_on_bank_account_id"
    t.index ["category"], name: "index_transactions_on_category"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["statement_file_id"], name: "index_transactions_on_statement_file_id"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "statement_files", "bank_accounts"
  add_foreign_key "transactions", "bank_accounts"
  add_foreign_key "transactions", "statement_files"
end
