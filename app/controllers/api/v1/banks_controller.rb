# frozen_string_literal: true

module Api
  module V1
    class BanksController < BaseController
      skip_before_action :authenticate_api_user!

      # GET /api/v1/banks
      # Public endpoint — returns all active banks for the mobile bank picker.
      # Optional filter: ?account_type=debit|credit
      def index
        banks = Bank.active.order(:name)

        if params[:account_type].present?
          banks = banks.select { |bank| bank.supports_account_type?(params[:account_type]) }
        end

        @banks = banks
      end
    end
  end
end
