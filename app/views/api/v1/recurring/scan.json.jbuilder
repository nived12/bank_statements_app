# frozen_string_literal: true

json.data do
  json.detected @series do |series|
    json.partial!("api/v1/shared/recurring_series", series: series)
  end
end
