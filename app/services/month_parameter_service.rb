# app/services/month_parameter_service.rb
class MonthParameterService
  class << self
    def parse_month_param(month_param)
      return Date.current.beginning_of_month unless month_param.present?

      begin
        # Parse YYYY-MM format to get the first day of the month
        parts = month_param.split("-")
        return Date.current.beginning_of_month if parts.length != 2

        year, month = parts.map(&:to_i)
        return Date.current.beginning_of_month if year <= 0 || month <= 0 || month > 12

        Date.new(year, month, 1)
      rescue => e
        Rails.logger.error "Error parsing month parameter: #{month_param} - #{e.message}"
        Date.current.beginning_of_month
      end
    end

    def format_month_for_display(date)
      date.strftime("%B %Y")
    end

    def format_month_for_param(date)
      date.strftime("%Y-%m")
    end
  end
end
