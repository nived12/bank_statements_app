# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::ReportsController
    # Generates downloadable reports for the authenticated user.
    #
    # Endpoints:
    # - GET /api/v1/reports/monthly?year=YYYY&month=MM&format=pdf
    #
    class ReportsController < BaseController
      ALLOWED_REPORT_FORMATS = %w[pdf].freeze

      # GET /api/v1/reports/monthly
      def monthly
        report_format = params[:report_format].to_s.downcase
        if report_format.present? && !ALLOWED_REPORT_FORMATS.include?(report_format)
          render_error(
            "INVALID_FORMAT",
            message: "Unsupported format. Allowed: pdf",
            status: :unprocessable_content
          )
          return
        end

        year = params[:year].to_i
        month = params[:month].to_i

        unless valid_period?(year, month)
          render_error(
            "INVALID_PERIOD",
            message: "Year and month are required and must be valid",
            status: :unprocessable_content
          )
          return
        end

        pdf_data = Reports::MonthlyPdfGenerator.call(user: current_user, year: year, month: month)
        filename = "vittio-reporte-#{year}-#{month.to_s.rjust(2, "0")}.pdf"

        send_data(pdf_data, filename: filename, type: "application/pdf", disposition: "attachment")
      rescue ArgumentError => e
        render_error("INVALID_PERIOD", message: e.message, status: :unprocessable_content)
      end

      private

      def valid_period?(year, month)
        year.between?(2000, Time.current.year + 1) && month.between?(1, 12)
      end
    end
  end
end
