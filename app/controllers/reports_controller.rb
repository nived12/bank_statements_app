class ReportsController < ApplicationController
  before_action :require_confirmed_user!

  def monthly
    year  = params[:year].to_i
    month = params[:month].to_i

    unless year.between?(2000, Time.current.year + 1) && month.between?(1, 12)
      redirect_back fallback_location: transactions_path,
        alert: t("reports.invalid_period")
      return
    end

    pdf_data = Reports::MonthlyPdfGenerator.call(user: current_user, year: year, month: month)
    filename = "vittio-reporte-#{year}-#{month.to_s.rjust(2, "0")}.pdf"

    send_data pdf_data, filename: filename, type: "application/pdf", disposition: "attachment"
  rescue ArgumentError => e
    redirect_back fallback_location: transactions_path, alert: e.message
  end
end
