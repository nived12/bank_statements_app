# StatementFile

## Table: `statement_files`

### Columns

| Column | Type | Nullable | Default | Index |
|--------|------|----------|---------|-------|
| `id` | `integer` | NO | NULL | - |
| `bank_account_id` | `integer` | NO | NULL | index_statement_files_on_bank_account_id |
| `status` | `string` | YES | NULL | - |
| `processed_at` | `datetime` | YES | NULL | - |
| `parsed_json` | `jsonb` | YES | {} | - |
| `created_at` | `datetime` | NO | NULL | - |
| `updated_at` | `datetime` | NO | NULL | - |
| `error_message` | `text` | YES | NULL | - |
| `user_id` | `integer` | NO | NULL | index_statement_files_on_user_id |
| `redaction_map` | `jsonb` | YES | {} | - |
| `redaction_hmac` | `string` | YES | NULL | index_statement_files_on_redaction_hmac |

### Indexes

| Name | Columns | Unique |
|------|---------|--------|
| `index_statement_files_on_bank_account_id` | `bank_account_id` | NO |
| `index_statement_files_on_redaction_hmac` | `redaction_hmac` | NO |
| `index_statement_files_on_user_id` | `user_id` | NO |

### Associations

- `belongs_to :user`
- `belongs_to :bank_account`
- `has_one :file_attachment`
- `has_one :file_blob`
- `has_many :transactions`
- `has_one :financial_summary`

### Validations

- `PresenceValidator on user`
- `PresenceValidator on bank_account`
- `PresenceValidator on file`
- `LengthValidator on redaction_hmac`