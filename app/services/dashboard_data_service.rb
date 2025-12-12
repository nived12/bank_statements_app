# app/services/dashboard_data_service.rb
class DashboardDataService
  class << self
    def fetch_dashboard_data(selected_month)
      {
        bank_accounts: fetch_bank_accounts,
        recent_transactions: fetch_recent_transactions,
        recent_statement_files: fetch_recent_statement_files,
        monthly_summary: fetch_monthly_summary(selected_month),
        category_summary: fetch_category_summary(selected_month),
        spending_trends: fetch_spending_trends(selected_month),
        monthly_stats: fetch_monthly_stats(selected_month),
        bank_summaries: calculate_bank_summaries,
        chart_data: prepare_chart_data(selected_month)
      }
    rescue => e
      DashboardErrorHandler.handle_data_load_error(e)
    end

    def fetch_available_months
      get_available_months
    rescue => e
      DashboardErrorHandler.handle_available_months_error(e)
    end

    private

    def fetch_bank_accounts
      Current.user.bank_accounts.includes(:bank, :statement_files, :transactions)
                  .order("banks.name")
    end

    def fetch_recent_transactions
      Current.user.transactions.includes(:bank_account, :category)
                  .order(date: :desc)
                  .limit(10)
    end

    def fetch_recent_statement_files
      Current.user.statement_files.includes(:bank_account)
                  .order(created_at: :desc)
                  .limit(3)
    end

    def fetch_monthly_summary(selected_month)
      FinancialCalculationService.calculate_monthly_summary(selected_month)
    end

    def fetch_category_summary(selected_month)
      FinancialCalculationService.calculate_category_summary(selected_month)
    end

    def fetch_spending_trends(selected_month)
      FinancialCalculationService.calculate_spending_trends(selected_month)
    end

    def fetch_monthly_stats(selected_month)
      FinancialCalculationService.calculate_monthly_stats(selected_month)
    end

    def calculate_bank_summaries
      bank_accounts = fetch_bank_accounts

      bank_accounts.map do |account|
        latest_statement = account.statement_files.order(created_at: :desc).first
        latest_transaction = account.transactions.order(date: :desc).first

        {
          account: account,
          balance: calculate_account_balance(account),
          recent_activity: latest_transaction&.date || latest_statement&.created_at,
          transaction_count: account.transactions.count,
          last_processed: latest_statement&.processed_at,
          status: latest_statement&.status
        }
      end
    end

    def calculate_account_balance(account)
      # Use the new effective_balance method that respects opening balance date
      account.effective_balance
    rescue => e
      Rails.logger.error "Error calculating balance for account #{account.id}: #{e.message}"
      # Fallback to opening balance if effective_balance fails
      account.opening_balance || 0
    end

    def prepare_chart_data(selected_month)
      {
        spending_trends: fetch_spending_trends(selected_month),
        category_summary: fetch_category_summary(selected_month)[:categories] || [],
        bank_summaries: format_bank_summaries_for_charts(calculate_bank_summaries)
      }
    end

    def format_bank_summaries_for_charts(bank_summaries)
      bank_summaries.map do |summary|
        {
          account: { bank_name: summary[:account].bank_display_name },
          balance: summary[:balance]
        }
      end
    end

    def get_available_months
      current_month = Date.current.beginning_of_month
      available_months = [ current_month ]

      # Add last 24 months
      24.times do |i|
        month = current_month - (i + 1).months
        available_months << month
      end

      # Get months with actual transaction data
      months_with_data = Current.user.transactions
                                   .select(Arel.sql("DATE_TRUNC('month', date)"))
                                   .distinct
                                   .pluck(Arel.sql("DATE_TRUNC('month', date)"))
                                   .compact

      # Add months with data
      months_with_data.each do |month|
        available_months << month unless available_months.include?(month)
      end

      # Sort and return unique months (newest first)
      available_months.uniq.sort.reverse
    end
  end
end
