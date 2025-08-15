# Transaction

## Table: `transactions`

### Columns

| Column | Type | Nullable | Default | Index |
|--------|------|----------|---------|-------|
| `id` | `integer` | NO | NULL | - |
| `bank_account_id` | `integer` | NO | NULL | index_transactions_on_bank_account_id |
| `statement_file_id` | `integer` | NO | NULL | index_transactions_on_statement_file_id |
| `date` | `date` | NO | NULL | index_transactions_on_date |
| `description` | `string` | NO | NULL | - |
| `amount` | `decimal` | NO | NULL | - |
| `transaction_type` | `string` | NO | NULL | index_transactions_on_transaction_type |
| `bank_entry_type` | `string` | YES | NULL | - |
| `merchant` | `string` | YES | NULL | - |
| `reference` | `string` | YES | NULL | - |
| `created_at` | `datetime` | NO | NULL | - |
| `updated_at` | `datetime` | NO | NULL | - |
| `user_id` | `integer` | NO | NULL | index_transactions_on_user_id |
| `category_id` | `integer` | YES | NULL | index_transactions_on_category_id |

### Indexes

| Name | Columns | Unique |
|------|---------|--------|
| `index_transactions_on_bank_account_id` | `bank_account_id` | NO |
| `index_transactions_on_category_id` | `category_id` | NO |
| `index_transactions_on_date` | `date` | NO |
| `index_transactions_on_statement_file_id` | `statement_file_id` | NO |
| `index_transactions_on_transaction_type` | `transaction_type` | NO |
| `index_transactions_on_user_id` | `user_id` | NO |

### Associations

- `belongs_to :user`
- `belongs_to :bank_account`
- `belongs_to :statement_file`
- `belongs_to :category`

### Validations

- `PresenceValidator on user`
- `PresenceValidator on bank_account`
- `PresenceValidator on statement_file`
- `PresenceValidator on date, description, amount, transaction_type`
- `NumericalityValidator on amount`