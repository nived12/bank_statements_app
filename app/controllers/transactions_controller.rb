class TransactionsController < ApplicationController
  def index
    scope = current_user.transactions.includes(:bank_account, :statement_file, :category)

    # Apply bank account filter if present
    scope = scope.where(bank_account_id: params[:bank_account_id]) if params[:bank_account_id].present?

    # Apply statement file filter if present
    if params[:statement_file_id].present?
      scope = scope.where(statement_file_id: params[:statement_file_id])
      @statement_file = current_user.statement_files.find(params[:statement_file_id])

      # Automatically include bank account filter when statement file is selected
      unless params[:bank_account_id].present?
        params[:bank_account_id] = @statement_file.bank_account_id
        scope = scope.where(bank_account_id: @statement_file.bank_account_id)
      end
    end

    # Apply transaction type filter if present
    scope = scope.where(transaction_type: params[:transaction_type]) if params[:transaction_type].present?

    # Apply date range filter if present
    if params[:from_date].present? || params[:to_date].present?
      scope = scope.date_range(params[:from_date], params[:to_date])
    end

    # Apply sorting
    scope = apply_sorting(scope)

    # Store filtered scope for stats calculations
    @filtered_transactions = scope

    # Reset to first page when filters change (only for non-AJAX requests)
    # Sorting changes should preserve pagination and filters
    # Simple approach: check if this is a fresh filter request
    page = if !request.xhr? && fresh_filter_request?
      1  # Reset to page 1 when filters change on initial page load
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

    # Load statement files for dropdown - filter by bank account if one is selected
    if params[:bank_account_id].present?
      @statement_files = current_user.statement_files
                                   .joins(:bank_account)
                                   .where(bank_account_id: params[:bank_account_id])
                                   .order(created_at: :desc)
    else
      @statement_files = current_user.statement_files
                                   .joins(:bank_account)
                                   .order(created_at: :desc)
    end

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
    result = Transactions::UpdateService.call(
      current_user,
      params[:id],
      params
    )

    if result.success?
      redirect_to transactions_path, notice: "Updated"
    else
      redirect_to transactions_path, alert: "Update failed"
    end
  end

  def statement_files
    result = Transactions::StatementFilesService.call(
      current_user,
      bank_account_id: params[:bank_account_id]
    )

    if result.success?
      render json: result.payload
    else
      render json: { error: "Failed to load statement files" }, status: :unprocessable_entity
    end
  end

  private

  def fresh_filter_request?
    # Much simpler approach: just check if filter parameters have changed
    # We'll store the current filter state in the session and compare it

    # Get current filter parameters
    current_filters = {
      "from_date" => params[:from_date],
      "to_date" => params[:to_date],
      "bank_account_id" => params[:bank_account_id],
      "statement_file_id" => params[:statement_file_id],
      "transaction_type" => params[:transaction_type]
    }

    # Get previous filter parameters from session
    previous_filters = session[:previous_transaction_filters] || {}

    # Check if any filter parameters have changed
    filters_changed = current_filters != previous_filters

    # Store current filters for next comparison
    session[:previous_transaction_filters] = current_filters

    # Return true if filters changed (requiring pagination reset)
    filters_changed
  end

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
end
