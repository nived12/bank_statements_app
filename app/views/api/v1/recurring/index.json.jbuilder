# frozen_string_literal: true

json.data do
  json.series @series do |series|
    json.partial!("api/v1/shared/recurring_series", series: series)
  end
  json.summary do
    json.monthly_total  @summary[:monthly_total].to_f
    json.annual_total   @summary[:annual_total].to_f
    json.active_count   @summary[:active_count]
    json.detected_count @summary[:detected_count]
    json.upcoming @summary[:upcoming] do |series|
      json.partial!("api/v1/shared/recurring_series", series: series)
    end
  end
end
