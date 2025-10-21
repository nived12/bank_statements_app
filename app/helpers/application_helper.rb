module ApplicationHelper
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
      "#{day_name}, #{local_datetime.day} de #{month_name} de #{local_datetime.year} a las #{local_datetime.strftime("%H:%M")}"
    when :date
      month_name = I18n.l(local_datetime, format: "%B")
      "#{local_datetime.day} de #{month_name} de #{local_datetime.year}"
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
        content_tag(:time, formatted_time,
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

  def format_currency(amount, currency = "USD")
    return "-" if amount.nil?

    number_to_currency(amount, unit: currency == "USD" ? "$" : currency, precision: 2, delimiter: ",")
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
end
