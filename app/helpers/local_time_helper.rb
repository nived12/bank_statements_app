module LocalTimeHelper
  # Generate a span element that will display UTC time as local time
  def local_time_tag(utc_time, format: "default", **options)
    content_tag :span,
      "",
      options.merge(
        "data-utc-time" => utc_time.iso8601,
        "data-format" => format
      )
  end

  # Generate a date input with local timezone handling
  def local_date_field(form, field_name, **options)
    form.date_field field_name,
      options.merge(
        "data-set-local-date" => true
      )
  end

  # Generate current month option with local timezone
  def current_month_option(**options)
    content_tag :option,
      "",
      options.merge(
        "data-current-month" => true,
        selected: true
      )
  end
end
