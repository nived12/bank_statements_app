# frozen_string_literal: true

module Assistant
  module Tools
    class GetNetWorth < Base
      NAME = "get_net_worth"
      DESCRIPTION = (
        "Returns the user's total net worth: all positive account balances minus credit card balances and active loan debts." # rubocop:disable Layout/LineLength
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {},
        required: []
      }.freeze

      def call
        accounts = @user.bank_accounts.to_a

        assets          = accounts.sum { |a| [a.effective_balance.to_f, 0].max }
        cc_debt         = accounts.select { |a| a.account_type == "credit" }
                                  .sum { |a| [-a.effective_balance.to_f, 0].max }
        debit_overdraft = accounts.select { |a| %w[debit cash].include?(a.account_type) }
                                  .sum { |a| [-a.effective_balance.to_f, 0].max }
        loan_debt       = @user.debts.where(status: "active").sum(:current_balance).to_f

        liabilities = cc_debt + debit_overdraft + loan_debt
        net_worth   = assets - liabilities

        success(
          {
                    net_worth: net_worth.round(2),
                    breakdown: {
                      assets: assets.round(2),
                      liabilities: liabilities.round(2),
                      credit_card_debt: cc_debt.round(2),
                      debit_overdraft: debit_overdraft.round(2),
                      loan_debt: loan_debt.round(2)
                    },
                    currency: "MXN"
                  }
        )
      end
    end
  end
end
