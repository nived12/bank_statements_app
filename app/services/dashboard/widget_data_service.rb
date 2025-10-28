# app/services/dashboard/widget_data_service.rb
class Dashboard::WidgetDataService < ApplicationService
  def initialize(selected_month, widget_id)
    @selected_month = selected_month
    @widget_id = widget_id
  end

  def call
    case @widget_id
    when "financial_health"
      calculate_financial_health
    when "income_expenses"
      calculate_income_expenses_comparison
    when "category_breakdown"
      calculate_category_breakdown
    when "cash_flow_timeline"
      calculate_cash_flow_timeline
    when "account_balances"
      calculate_account_balances
    when "recent_transactions"
      fetch_recent_transactions
    else
      {}
    end
  end

  private

  def calculate_financial_health
    month_start = @selected_month.beginning_of_month
    month_end = @selected_month.end_of_month

    transactions = Current.user.transactions.where(date: month_start..month_end)
    income = transactions.where(transaction_type: "income").sum(:amount)
    expenses = transactions.where(transaction_type: ["fixed_expense", "variable_expense"]).sum(:amount)
    net = income + expenses

    savings_rate = income > 0 ? ((income + expenses) / income * 100).round(1) : 0

    {
      net_worth: calculate_total_net_worth,
      savings_rate: savings_rate,
      cash_flow_positive: net >= 0,
      monthly_net: net,
      month: I18n.l(@selected_month, format: "%B %Y")
    }
  end

  def calculate_income_expenses_comparison
    month_start = @selected_month.beginning_of_month
    month_end = @selected_month.end_of_month

    transactions = Current.user.transactions.where(date: month_start..month_end)
    income = transactions.where(transaction_type: "income").sum(:amount)
    expenses = transactions.where(transaction_type: ["fixed_expense", "variable_expense"]).sum(:amount).abs

    previous_month_start = (@selected_month - 1.month).beginning_of_month
    previous_month_end = (@selected_month - 1.month).end_of_month
    previous_transactions = Current.user.transactions.where(date: previous_month_start..previous_month_end)
    previous_income = previous_transactions.where(transaction_type: "income").sum(:amount)
    previous_expenses = previous_transactions.where(transaction_type: ["fixed_expense", "variable_expense"]).sum(:amount).abs

    {
      income: { current: income, previous: previous_income, trend: calculate_trend(income, previous_income) },
      expenses: { current: expenses, previous: previous_expenses, trend: calculate_trend(expenses, previous_expenses) }
    }
  end

  def calculate_category_breakdown
    month_start = @selected_month.beginning_of_month
    month_end = @selected_month.end_of_month

    categories = Current.user.transactions
                          .where(date: month_start..month_end)
                          .where(transaction_type: ["fixed_expense", "variable_expense"])
                          .joins(:category)
                          .group("categories.name")
                          .sum(:amount)

    # Convert to absolute values and sort
    categories.map { |name, amount| { name: name || "Uncategorized", amount: amount.abs } }
              .sort_by { |c| -c[:amount] }
              .take(5)
  end

  def calculate_cash_flow_timeline
    FinancialCalculationService.calculate_spending_trends(@selected_month)
  end

  def calculate_account_balances
    Current.user.bank_accounts.map do |account|
      {
        name: account.bank_display_name,
        balance: account.effective_balance || 0,
        account_number: account.account_number.last(4)
      }
    end
  end

  def fetch_recent_transactions
    Current.user.transactions.includes(:bank_account, :category)
              .order(date: :desc)
              .limit(5)
              .map do |transaction|
                {
                  id: transaction.id,
                  description: transaction.description,
                  amount: transaction.amount,
                  date: transaction.date,
                  category: transaction.category&.name || "Uncategorized",
                  account: transaction.bank_account.custom_name
                }
              end
  end

  def calculate_total_net_worth
    Current.user.bank_accounts.sum do |account|
      balance = account.effective_balance || 0
      balance || 0
    end
  rescue => e
    Rails.logger.error "Error calculating net worth: #{e.message}"
    0
  end

  def calculate_trend(current, previous)
    return "neutral" if previous == 0

    percentage_change = ((current - previous) / previous * 100).round(1)
    if percentage_change > 5
      "up"
    elsif percentage_change < -5
      "down"
    else
      "neutral"
    end
  end
end
