# BankAccount

## Table: `bank_accounts`

### Columns

| Column | Type | Nullable | Default | Index |
|--------|------|----------|---------|-------|
| `id` | `integer` | NO | NULL | - |
| `bank_name` | `string` | YES | NULL | - |
| `account_number` | `string` | YES | NULL | - |
| `currency` | `string` | YES | NULL | - |
| `opening_balance` | `decimal` | YES | NULL | - |
| `created_at` | `datetime` | NO | NULL | - |
| `updated_at` | `datetime` | NO | NULL | - |
| `user_id` | `integer` | NO | NULL | index_bank_accounts_on_user_id |

### Indexes

| Name | Columns | Unique |
|------|---------|--------|
| `index_bank_accounts_on_user_id` | `user_id` | NO |

### Associations

- `belongs_to :user`
- `has_many :statement_files`

### Validations

- `PresenceValidator on user`
- `PresenceValidator on bank_name, account_number`