module ApplicationHelper
  include Pagy::Frontend

  # Single source of truth for the public support address. Submitted to App Store
  # Connect and Play Console, so it must stay a live mailbox. Legal documents
  # intentionally keep the literal address — their text is versioned and should
  # not change without a document version bump.
  SUPPORT_EMAIL = "support@vitt.io"

  def support_email
    SUPPORT_EMAIL
  end

  def format_local_time(datetime, format: :default, **options)
    return "" if datetime.nil?

    # Handle Date objects differently from DateTime/Time objects
    if datetime.is_a?(Date) && !datetime.is_a?(DateTime) && !datetime.is_a?(Time)
      # For pure Date objects, we don't need timezone conversion
      local_datetime = datetime
    else
      # Convert to local timezone (using Time.zone which is set by TimezoneConcern)
      local_datetime = datetime.in_time_zone(Time.zone)
    end

    formatted_time = case format.to_sym
    when :full
      day_name = I18n.l(local_datetime, format: "%A")
      month_name = I18n.l(local_datetime, format: "%B")
      # rubocop:disable Layout/LineLength
      "#{day_name}, #{local_datetime.day} de #{month_name} de #{local_datetime.year} a las #{local_datetime.strftime("%H:%M")}"
      # rubocop:enable Layout/LineLength
    when :date
      month_name = I18n.l(local_datetime, format: "%B")
      "#{local_datetime.day} de #{month_name} de #{local_datetime.year}"
    when :compact_date
      I18n.l(local_datetime.to_date, format: :compact)
    when :short_date
      local_datetime.strftime("%d/%m/%Y")
    when :time
      local_datetime.strftime("%H:%M")
    else
      local_datetime.strftime("%d/%m/%Y %H:%M")
    end

    # Use content_tag if available (in Rails view context), otherwise return plain text
    if respond_to?(:content_tag)
      if datetime.is_a?(Date) && !datetime.is_a?(DateTime) && !datetime.is_a?(Time)
        # Pure Date objects: render as span without timezone data
        content_tag(:span, formatted_time, class: "local-date", **options)
      else
        # DateTime/Time objects: render as time with timezone conversion data
        content_tag(
          :time, formatted_time,
          datetime: local_datetime.iso8601,
          data: {
            utc_time: datetime.iso8601,
            format: format.to_s,
            timezone: Time.zone.name  # Dynamic timezone
          },
          class: "local-time",
                    **options
        )
      end
    else
      formatted_time
    end
  end

  # Display symbol for a billing currency. Stripe charges MXN, but App Store
  # subscribers are billed in their own currency, so unknown codes render as the
  # code itself ("BRL 49.00") rather than a wrong symbol.
  BILLING_CURRENCY_SYMBOLS = { "MXN" => "MX$", "USD" => "US$", "EUR" => "€" }.freeze

  def billing_currency_symbol(currency)
    return "MX$" if currency.blank?

    BILLING_CURRENCY_SYMBOLS.fetch(currency.upcase, "#{currency.upcase} ")
  end

  def format_currency(amount, currency = "USD")
    return "-" if amount.nil?

    number_to_currency(amount, unit: currency == "USD" ? "$" : currency, precision: 2, delimiter: ",")
  end

  # MXN-aware formatter matching mobile app (es-MX tabular nums, +/- signs)
  def format_money(amount, currency: "MXN", variant: :auto, css_class: nil)
    return content_tag(:span, "-", class: css_class) if amount.nil?

    numeric = amount.to_f
    formatted = number_to_currency(numeric.abs, unit: "$", precision: 2, delimiter: ",", format: "%u%n")

    text = case variant.to_sym
    when :always_sign
      numeric >= 0 ? "+#{formatted}" : "−#{formatted}"
    when :no_sign
      formatted
    when :hero
      formatted
    else
      numeric.negative? ? "−#{formatted}" : formatted
    end

    color_class = if variant.to_sym == :hero
      "money-hero"
    elsif numeric.zero?
      "money-zero"
    elsif numeric.positive?
      "money-positive"
    else
      "money-negative"
    end

    content_tag(:span, text, class: [color_class, "tabular-nums", css_class].compact.join(" "))
  end

  def mobile_date_label(date)
    return t("mobile.transactions.today") if date == Date.current
    return t("mobile.transactions.yesterday") if date == Date.current - 1.day

    I18n.l(date, format: :short_day_month)
  end

  # Plain-text date for transaction row subtitle (no HTML tags)
  def mobile_tx_meta_date(date)
    return "" if date.nil?

    d = date.to_date
    return t("mobile.transactions.today") if d == Date.current
    return t("mobile.transactions.yesterday") if d == Date.current - 1.day

    if d.year == Date.current.year
      I18n.l(d, format: "%b %-d")
    else
      I18n.l(d, format: :compact)
    end
  end

  def mobile_tx_meta_line(transaction)
    parts = [mobile_tx_meta_date(transaction.date)]

    if transaction.bank_account
      account_name = transaction.bank_account.custom_name.presence || transaction.bank_account.display_name
      parts << account_name if account_name.present?

      unless transaction.bank_account.cash?
        last4 = transaction.bank_account.account_number.to_s.last(4)
        parts << last4 if last4.present?
      end
    end

    parts.compact_blank.join(" · ")
  end

  def account_type_dot_class(account_type)
    case account_type.to_s
    when "credit" then "mobile-account-chip-dot--credit"
    when "cash" then "mobile-account-chip-dot--cash"
    else "mobile-account-chip-dot--checking"
    end
  end

  def account_icon_bg_class(account_type)
    case account_type.to_s
    when "credit" then "bg-violet-100 text-violet-800"
    when "cash" then "bg-emerald-100 text-emerald-800"
    else "bg-sky-100 text-sky-800"
    end
  end

  def finances_nav_active?
    %w[finances goals savings debts].include?(controller_name)
  end

  # Mobile bottom nav: Ionicons outline (inactive) / solid (active), matching the React Native app
  def mobile_nav_icon(name, active: false, css_class: "w-[22px] h-[22px]")
    ionicon_svg(name, variant: active ? "solid" : "outline", css_class: css_class)
  end

  def format_percentage(value, total)
    return "0%" if total.zero?

    percentage = (value / total * 100).round(1)
    "#{percentage}%"
  end

  def trend_icon(value, previous_value)
    return "neutral" if previous_value.nil? || previous_value.zero?

    if value > previous_value
      "up"
    elsif value < previous_value
      "down"
    else
      "neutral"
    end
  end

  def trend_color(value, previous_value)
    return "text-slate-500" if previous_value.nil? || previous_value.zero?

    if value > previous_value
      "text-green-600"
    elsif value < previous_value
      "text-red-600"
    else
      "text-slate-500"
    end
  end

  def card_color_class(amount)
    if amount >= 0
      "bg-green-50 border-green-200"
    else
      "bg-red-50 border-red-200"
    end
  end

  DESKTOP_FIELD_LABEL_CLASS = "block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
  MOBILE_FORM_LABEL_CLASS = "block text-sm font-medium text-slate-600 dark:text-slate-400 mb-1.5"

  # Form field label helpers — desktop defaults; pass class: MOBILE_FORM_LABEL_CLASS in mobile partials only
  def required_field_label(form, field, text, options = {})
    css_class = options[:class] || DESKTOP_FIELD_LABEL_CLASS
    form.label field, class: css_class do
      safe_join([text, " ", content_tag(:span, "*", class: "text-red-500")])
    end
  end

  def optional_field_label(form, field, text, options = {})
    css_class = options[:class] || DESKTOP_FIELD_LABEL_CLASS
    form.label field, class: css_class do
      safe_join([text, " ", content_tag(:span, "(#{t("form_actions.optional")})", class: "text-slate-400 text-xs")])
    end
  end

  def mobile_field_label(form, field, text, required: false)
    form.label field, class: MOBILE_FORM_LABEL_CLASS do
      required ? safe_join([text, " ", content_tag(:span, "*", class: "text-red-400")]) : text
    end
  end

  # Flash message helpers
  def flash_class(type)
    case type.to_sym
    when :notice, :success
      "bg-green-50 border border-green-200"
    when :alert, :error
      "bg-red-50 border border-red-200"
    when :warning
      "bg-yellow-50 border border-yellow-200"
    else
      "bg-blue-50 border border-blue-200"
    end
  end

  def flash_icon(type)
    icon_class = case type.to_sym
    when :notice, :success
      "text-green-400"
    when :alert, :error
      "text-red-400"
    when :warning
      "text-yellow-400"
    else
      "text-blue-400"
    end

    # rubocop:disable Layout/LineLength
    path = case type.to_sym
    when :notice, :success
      "M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
    when :alert, :error
      "M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
    when :warning
      "M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
    else
      "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
    end
    # rubocop:enable Layout/LineLength

    content_tag(:svg, class: "h-5 w-5 #{icon_class}", fill: "currentColor", viewBox: "0 0 20 20") do
      content_tag(:path, nil, "fill-rule": "evenodd", d: path, "clip-rule": "evenodd")
    end
  end

  def flash_text_class(type)
    case type.to_sym
    when :notice, :success
      "text-sm font-medium text-green-800"
    when :alert, :error
      "text-sm font-medium text-red-800"
    when :warning
      "text-sm font-medium text-yellow-800"
    else
      "text-sm font-medium text-blue-800"
    end
  end

  def flash_button_class(type)
    case type.to_sym
    when :notice, :success
      "text-green-400 hover:text-green-600 focus:ring-green-500"
    when :alert, :error
      "text-red-400 hover:text-red-600 focus:ring-red-500"
    when :warning
      "text-yellow-400 hover:text-yellow-600 focus:ring-yellow-500"
    else
      "text-blue-400 hover:text-blue-600 focus:ring-blue-500"
    end
  end

  def flatten_categories_hierarchically(categories)
    categories.flat_map { |parent| [parent] + parent.children.to_a }
  end

  # Returns the best avatar URL for a user: uploaded image > stored URL > generated initials
  def user_avatar_url(user)
    return url_for(user.avatar_image) if user.avatar_image.attached?

    user.avatar_url
  end

  # Landing: supported bank logo filenames under app/assets/images/banks (keep in sync with supported_banks partial)
  def landing_bank_slugs
    %w[bbva banorte hsbc santander scotiabank banamex nu revolut banregio banbajio inbursa afirme azteca].freeze
  end
end
