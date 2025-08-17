class TransactionsController < ApplicationController
  def index
    scope = current_user.transactions.includes(:bank_account, :statement_file, :category)

    # Apply bank account filter if present
    scope = scope.where(bank_account_id: params[:bank_account_id]) if params[:bank_account_id].present?

    # Apply sorting
    scope = apply_sorting(scope)

    @transactions = scope.limit(500)
    @bank_accounts = current_user.bank_accounts.order(:bank_name, :account_number)

    # Store current sort parameters for view
    @current_sort = params[:sort] || "date"
    @current_direction = params[:direction] || "desc"
  end

  def update
    transaction = current_user.transactions.find(params[:id])
    if transaction.update(permitted_params)
      redirect_to "/transactions", notice: "Updated"
    else
      redirect_to "/transactions", alert: "Update failed"
    end
  end

  private

  def apply_sorting(scope)
    sort_field = params[:sort] || "date"
    direction = params[:direction] || "desc"

    case sort_field
    when "date"
      scope.order(date: direction.to_sym)
    when "amount"
      scope.order(amount: direction.to_sym)
    when "description"
      scope.order(description: direction.to_sym)
    when "transaction_type"
      scope.order(transaction_type: direction.to_sym)
    when "category"
      scope.joins(:category).order('categories.name': direction.to_sym)
    when "merchant"
      scope.order(merchant: direction.to_sym)
    when "bank_account"
      scope.joins(:bank_account).order('bank_accounts.bank_name': direction.to_sym)
    else
      scope.order(date: :desc) # Default fallback
    end
  end

  def permitted_params
    params.require(:transaction).permit(:transaction_type, :category_id, :merchant, :reference)
  end
end
