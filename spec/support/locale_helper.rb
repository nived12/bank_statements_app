# spec/support/locale_helper.rb
module LocaleHelper
  def with_locale(locale)
    I18n.with_locale(locale) { yield }
  end

  def set_test_locale_to_spanish
    I18n.locale = :es
  end
end

RSpec.configure do |config|
  config.include LocaleHelper

  # Set locale to Spanish for all tests
  config.before(:each) do
    I18n.locale = :es
  end

  # Reset locale after each test
  config.after(:each) do
    I18n.locale = I18n.default_locale
  end
end
