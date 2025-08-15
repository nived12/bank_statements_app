# Category

## Table: `categories`

### Columns

| Column | Type | Nullable | Default | Index |
|--------|------|----------|---------|-------|
| `id` | `integer` | NO | NULL | - |
| `user_id` | `integer` | YES | NULL | idx_categories_user_parent_name, index_categories_on_user_id |
| `name` | `string` | NO | NULL | idx_categories_user_parent_name |
| `parent_id` | `integer` | YES | NULL | idx_categories_user_parent_name, index_categories_on_parent_id |
| `created_at` | `datetime` | NO | NULL | - |
| `updated_at` | `datetime` | NO | NULL | - |

### Indexes

| Name | Columns | Unique |
|------|---------|--------|
| `idx_categories_user_parent_name` | `user_id, parent_id, name` | YES |
| `index_categories_on_parent_id` | `parent_id` | NO |
| `index_categories_on_user_id` | `user_id` | NO |

### Associations

- `belongs_to :user`
- `belongs_to :parent`
- `has_many :children`
- `has_many :transactions`

### Validations

- `PresenceValidator on name`