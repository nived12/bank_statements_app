# Internationalization (i18n) Guide

This application now supports multiple languages with a focus on English and Latin/Mexican Spanish.

## Supported Languages

- **English (en)** - Default language
- **Spanish (es)** - Latin/Mexican Spanish

## How to Use

### For Users

1. **Language Switcher**: Look for the language switcher in the top-right corner of the application header (next to your profile)
2. **Click the Language Button**: Click on the language button showing "EN" or "ES"
3. **Select Language**: Choose your preferred language from the dropdown menu
4. **Automatic Redirect**: The page will reload in your selected language

### For Developers

#### Adding New Translations

1. **English Locale** (`config/locales/en.yml`):
   ```yaml
   en:
     new_key: "English text"
   ```

2. **Spanish Locale** (`config/locales/es.yml`):
   ```yaml
   es:
     new_key: "Texto en español"
   ```

#### Using Translations in Views

```erb
<!-- Simple translation -->
<%= t('hello') %>

<!-- Translation with interpolation -->
<%= t('welcome_back', name: current_user.name) %>

<!-- Pluralization -->
<%= t('across_accounts', count: @accounts.count) %>
```

#### Using Translations in Controllers

```ruby
# Simple translation
flash[:notice] = t('success')

# Translation with interpolation
flash[:notice] = t('user_created', name: @user.name)
```

#### Using Translations in Models

```ruby
class User < ApplicationRecord
  validates :email, presence: { message: :blank }
  
  # Custom validation messages
  validates :name, presence: { message: I18n.t('errors.messages.blank') }
end
```

## Technical Implementation

### Configuration

- **Default Locale**: English (`:en`)
- **Available Locales**: `[:en, :es]`
- **Fallbacks**: Enabled (falls back to default locale if translation missing)
- **Routes**: Locale-aware routing with `/:locale` prefix

### Files

- `config/locales/en.yml` - English translations
- `config/locales/es.yml` - Spanish translations
- `app/controllers/concerns/locale_concern.rb` - Locale handling logic
- `app/views/shared/_language_switcher.html.erb` - Language switcher component

### Locale Detection

The application detects the user's preferred language through:

1. **URL Parameter**: `?locale=es` or `/es/dashboard`
2. **HTTP Header**: `Accept-Language` header
3. **Default**: Falls back to English if no preference detected

### Adding New Languages

To add a new language (e.g., French):

1. Create `config/locales/fr.yml`
2. Add `:fr` to `config.i18n.available_locales` in `config/application.rb`
3. Update the language switcher partial
4. Add French translations

## Current Translations

The application includes translations for:

- **Navigation**: Dashboard, Bank Accounts, Transactions, etc.
- **Dashboard**: Financial metrics, charts, and summaries
- **Forms**: Labels, buttons, and validation messages
- **Messages**: Success, error, and informational messages
- **Time Formats**: Date and time formatting
- **Number Formats**: Currency and number formatting

## Best Practices

1. **Always use translation keys** instead of hardcoded text
2. **Use interpolation** for dynamic content
3. **Provide context** in translation keys when needed
4. **Test both languages** during development
5. **Keep translations organized** by feature or section
6. **Use pluralization** for countable items

## Testing

To test the internationalization:

1. Start the application
2. Navigate to any page
3. Use the language switcher to change languages
4. Verify that all text changes appropriately
5. Check that URLs include the locale prefix when not using default language

## Troubleshooting

### Common Issues

1. **Missing Translations**: Check that keys exist in both locale files
2. **Route Issues**: Ensure routes are wrapped in the locale scope
3. **Locale Not Persisting**: Check that the locale concern is included in ApplicationController

### Debugging

To debug locale issues:

```ruby
# In Rails console or controller
puts I18n.locale
puts I18n.available_locales
puts I18n.t('some_key')
```

## Future Enhancements

Potential improvements:

1. **User Preference Storage**: Save language preference in user profile
2. **Auto-detection**: Better browser language detection
3. **RTL Support**: Right-to-left language support
4. **Translation Management**: Admin interface for managing translations
5. **API Localization**: Localize API responses
