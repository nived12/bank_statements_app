# User

## Table: `users`

### Columns

| Column | Type | Nullable | Default | Index |
|--------|------|----------|---------|-------|
| `id` | `integer` | NO | NULL | - |
| `first_name` | `string` | NO | NULL | - |
| `last_name` | `string` | NO | NULL | - |
| `email` | `string` | NO | NULL | index_users_on_email |
| `password_digest` | `string` | YES | NULL | - |
| `created_at` | `datetime` | NO | NULL | - |
| `updated_at` | `datetime` | NO | NULL | - |

### Indexes

| Name | Columns | Unique |
|------|---------|--------|
| `index_users_on_email` | `email` | YES |

### Associations

- `has_many :bank_accounts`
- `has_many :statement_files`
- `has_many :transactions`
- `has_many :categories`

### Validations

- `ConfirmationValidator on password`
- `PresenceValidator on first_name, last_name`
- `PresenceValidator on email`
- `UniquenessValidator on email`