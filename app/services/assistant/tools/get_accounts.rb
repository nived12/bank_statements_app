# frozen_string_literal: true

module Assistant
  module Tools
    class GetAccounts < Base
      NAME = "get_accounts"
      DESCRIPTION = "Returns the user's bank accounts with current balances. Optionally filter by account name."
      SCHEMA = {
        type: "object",
        properties: {
          account_name: { type: "string", description: "Partial name match to filter a specific account" }
        },
        required: []
      }.freeze

      def call
        scope = @user.bank_accounts

        if @args[:account_name].present?
          scope = scope.where("custom_name ILIKE ?", "%#{@args[:account_name]}%")
        end

        accounts = scope.map do |acc|
          {
            id: acc.id,
            name: acc.custom_name || acc.account_number,
            account_type: acc.account_type,
            balance: acc.effective_balance.to_f,
            currency: acc.currency || "MXN"
          }
        end

        success({ accounts: accounts, count: accounts.size, currency: "MXN" })
      end
    end
  end
end
