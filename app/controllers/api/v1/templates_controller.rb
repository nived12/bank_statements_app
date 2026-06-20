# frozen_string_literal: true

module Api
  module V1
    class TemplatesController < BaseController
      # GET /api/v1/templates
      # Read-only catalog of starter savings/debt templates the mobile app uses
      # to pre-fill a new savings or debt form. Names/descriptions are localized
      # from the Accept-Language header so Rails i18n stays the single source of
      # truth for template copy across web and mobile.
      def index
        I18n.with_locale(requested_locale) do
          @savings = FinancialTemplate::SAVINGS
          @debts = FinancialTemplate::DEBTS
          render :index
        end
      end

      private

      def requested_locale
        tag = request.headers["Accept-Language"].to_s.split(",").first.to_s.split("-").first.to_s.downcase
        I18n.available_locales.map(&:to_s).include?(tag) ? tag : I18n.default_locale
      end
    end
  end
end
