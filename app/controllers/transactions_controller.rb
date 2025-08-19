class TransactionsController < ApplicationController
  def index
    scope = current_user.transactions.includes(:bank_account, :statement_file, :category)

    # Apply bank account filter if present
    scope = scope.where(bank_account_id: params[:bank_account_id]) if params[:bank_account_id].present?

    # Apply sorting
    scope = apply_sorting(scope)

    # Reset to first page when sorting changes (only for non-AJAX requests)
    page = if !request.xhr? && (params[:sort].present? || params[:direction].present?)
      1  # Always start from page 1 when sorting on initial page load
    else
      # Ensure page is a valid integer, default to 1 if invalid
      begin
        page_num = Integer(params[:page]) if params[:page].present?
        page_num || 1
      rescue ArgumentError
        1
      end
    end

    # Use Pagy for pagination with error handling
    begin
      @pagy, @transactions = pagy(scope, items: 20, page: page)
    rescue Pagy::OverflowError
      # If page is beyond total pages, reset to page 1
      @pagy, @transactions = pagy(scope, items: 20, page: 1)
    end
    @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)

    # Store current sort parameters for view
    @current_sort = params[:sort] || "date"
    @current_direction = params[:direction] || "desc"

    # Handle AJAX requests for infinite scrolling
    if request.xhr? && params[:page].present?
      page_offset = (@pagy.page - 1) * 20

      # Return HTML partial for infinite scrolling
      render partial: "transactions/transaction_rows", locals: {
        transactions: @transactions,
        page_offset: page_offset
      }
    end
  end

  def update
    transaction = current_user.transactions.find(params[:id])
    if transaction.update(permitted_params)
      redirect_to "/transactions", notice: "Updated"
    else
      redirect_to "/transactions", alert: "Update failed"
    end
  end

  # load_more action removed - now handled by index with AJAX

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
      scope.joins(bank_account: :bank).order('banks.name': direction.to_sym)
    else
      scope.order(date: :desc) # Default fallback
    end
  end

  def permitted_params
    params.require(:transaction).permit(:transaction_type, :category_id, :merchant, :reference)
  end
end
