module ApplicationHelper
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
