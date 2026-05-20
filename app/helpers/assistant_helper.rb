# frozen_string_literal: true

module AssistantHelper
  # Groups conversations into Claude-style time buckets for the history rail.
  # Returns one of: :today, :yesterday, :this_week, :earlier.
  def recency_bucket(time)
    return :earlier if time.nil?

    today = Time.current.to_date
    date  = time.in_time_zone(Time.zone).to_date

    return :today      if date == today
    return :yesterday  if date == today - 1
    return :this_week  if date >= today - 6

    :earlier
  end
end
