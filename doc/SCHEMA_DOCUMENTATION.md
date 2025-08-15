# Schema Documentation for Rails 8

Since the `annotate` gem is not supported in Rails 8, here are several alternatives to help you view table schema information without jumping to `schema.rb`.

## 🚀 Quick Start

### 1. **Model Annotation (Like Annotate Gem)**
Add schema information directly to your model files as comments:

```bash
bundle exec rake schema:annotate
```

This will add schema comments like this to your models:

```ruby
class Transaction < ApplicationRecord
# == Schema Information
#
# Table name: transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_account_id      :integer         not null   no default           index: index_transactions_on_bank_account_id
#  statement_file_id    :integer         not null   no default           index: index_transactions_on_statement_file_id
#  date                 :date            not null   no default           index: index_transactions_on_date
#  description          :string          not null   no default           no index
#  amount               :decimal         not null   no default           no index
#  transaction_type     :string          not null   no default           index: index_transactions_on_transaction_type
#  bank_entry_type      :string          null       no default           no index
#  merchant             :string          null       no default           no index
#  reference            :string          null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           index: index_transactions_on_user_id
#  user_id              :integer         not null   no default           index: index_transactions_on_user_id
#  category_id          :integer         null       no default           index: index_transactions_on_category_id
#
# Indexes:
#  index_transactions_on_bank_account_id (bank_account_id) non-unique
#  index_transactions_on_category_id (category_id) non-unique
#  index_transactions_on_date     (date) non-unique
#  index_transactions_on_statement_file_id (statement_file_id) non-unique
#  index_transactions_on_transaction_type (transaction_type) non-unique
#  index_transactions_on_user_id  (user_id) non-unique
#
  belongs_to :user
  # ... rest of your model code
end
```

### 2. **Markdown Documentation**
Generate comprehensive markdown files for each model:

```bash
bundle exec rake schema:docs
```

This creates `doc/models/` directory with individual `.md` files for each model.

### 3. **Quick Table Lookup**
Get schema information for a specific table from the command line:

```bash
# List all tables
bundle exec rake schema:tables

# Look up specific table
bundle exec rake "schema:lookup[transactions]"
bundle exec rake "schema:lookup[users]"
bundle exec rake "schema:lookup[categories]"
```

## 📋 Available Rake Tasks

| Task | Description | Usage |
|------|-------------|-------|
| `schema:annotate` | Add schema comments to model files | `bundle exec rake schema:annotate` |
| `schema:docs` | Generate markdown documentation | `bundle exec rake schema:docs` |
| `schema:tables` | List all tables with column/index counts | `bundle exec rake schema:tables` |
| `schema:lookup[table]` | Show detailed schema for specific table | `bundle exec rake "schema:lookup[transactions]"` |

## 🔧 Configuration

### Auto-annotation in Development
You can add this to your `config/environments/development.rb` to automatically annotate models:

```ruby
# Auto-annotate models in development
if Rails.env.development?
  config.after_initialize do
    system('bundle exec rake schema:annotate') if Rails.env.development?
  end
end
```

### Git Hooks
Add to your `.gitignore` to avoid committing annotation changes:

```gitignore
# Ignore schema annotation changes (optional)
app/models/*.rb
!app/models/*.rb.bak
```

## 💡 Usage Tips

### 1. **For Development**
- Use `schema:annotate` to add schema info directly to models
- Run it after migrations or schema changes
- The comments are automatically updated when you run the task

### 2. **For Documentation**
- Use `schema:docs` to generate markdown files
- Great for team documentation or external tools
- Can be committed to version control

### 3. **For Quick Lookups**
- Use `schema:lookup[table_name]` when you need info about a specific table
- Use `schema:tables` to get an overview of all tables

### 4. **For CI/CD**
- Use `schema:docs` in your build process to generate documentation
- Can be used to validate schema consistency

## 🆚 Comparison with Annotate Gem

| Feature | Annotate Gem | Our Solution |
|---------|--------------|--------------|
| Rails 8 Support | ❌ No | ✅ Yes |
| Model Comments | ✅ Yes | ✅ Yes |
| Markdown Docs | ❌ No | ✅ Yes |
| Command Line Lookup | ❌ No | ✅ Yes |
| Customizable | ⚠️ Limited | ✅ Yes |
| Performance | ✅ Fast | ✅ Fast |

## 🚨 Troubleshooting

### Common Issues

1. **Models not loading**: Make sure your models are properly defined and don't have syntax errors
2. **Database connection**: Ensure your database is running and accessible
3. **Permission errors**: Check file write permissions in your app directory

### Debug Mode

Run tasks with `--trace` for detailed error information:

```bash
bundle exec rake schema:annotate --trace
```

## 🔄 Updating Annotations

After making schema changes (migrations), run:

```bash
bundle exec rake schema:annotate
```

This will update all model files with the latest schema information.

## 📚 Additional Resources

- [Rails Schema Documentation](https://guides.rubyonrails.org/active_record_migrations.html#schema-dumping-and-you)
- [Active Record Query Interface](https://guides.rubyonrails.org/active_record_querying.html)
- [Database Migrations](https://guides.rubyonrails.org/active_record_migrations.html)

---

**Note**: These tasks are designed to work with Rails 8 and provide the same functionality as the annotate gem, plus additional features for modern Rails development workflows.
