class TransactionsController < ApplicationController
  def index
    result = Transactions::Lister.call(current_user, request_params)

    if result.success?
      load_transaction_data(result.payload)
      handle_pagination
      load_dropdown_data

      respond_to do |format|
        format.html do
          handle_ajax_request
          # If handle_ajax_request didn't render anything, Rails will render index.html.erb
        end
        format.json do
          @filters = request_params
          calculate_stats
          @stats ||= {}
          # Rails will automatically render index.json.jbuilder
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to transactions_path(request_params), alert: "Failed to load transactions" }
        format.json { render json: { error: "Failed to load transactions" }, status: :unprocessable_entity }
      end
    end
  end

  def new
    @transaction = current_user.transactions.new(date: Date.current)
    load_dropdown_data
  end

  def edit
    @transaction = current_user.transactions.find(params[:id])
    load_dropdown_data
  end

  def create
    result = Transactions::CreateService.call(transaction_params)

    if result.success?
      redirect_to transactions_path, notice: "Transaction created successfully"
    else
      # Re-render the form with errors, preserving layout
      params_with_defaults = transaction_params.merge(date: transaction_params[:date] || Date.current)
      # Remove transfer_account_id since it's not a transaction attribute
      params_with_defaults = params_with_defaults.except(:transfer_account_id)
      @transaction = current_user.transactions.new(params_with_defaults)

      # Copy errors from service result to the transaction object
      result.errors.each do |error|
        @transaction.errors.add(error.attribute, error.message)
      end

      load_dropdown_data
      flash.now[:alert] = "Failed to create transaction: #{result.errors.full_messages.join(", ")}"
      render :new, status: :unprocessable_entity
    end
  end

  def update
    result = Transactions::UpdateService.call(
      params[:id],
      transaction_params
    )

    if result.success?
      redirect_to transactions_path, notice: "Transaction updated successfully"
    else
      # Re-render the form with errors, preserving layout
      # Try to find transaction, but handle case where it doesn't exist or belongs to different user
      @transaction = current_user.transactions.find_by(id: params[:id])

      if @transaction
        @transaction.assign_attributes(transaction_params)
      else
        # Transaction not found or doesn't belong to user - redirect with error
        redirect_to transactions_path, alert: "Transaction not found or you don't have permission to update it"
        return
      end

      # Copy errors from service result to the transaction object
      result.errors.each do |error|
        @transaction.errors.add(error.attribute, error.message)
      end

      load_dropdown_data
      flash.now[:alert] = "Failed to update transaction: #{result.errors.full_messages.join(", ")}"
      render :edit, status: :unprocessable_entity
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

  def check_duplicates
    # Find statement files with status :parsed that have pending duplicates
    statement_files_with_duplicates = current_user.statement_files
                                                  .where(status: :parsed)
                                                  .joins(:pending_transactions)
                                                  .distinct
                                                  .includes(:bank_account, :bank)

    duplicates_data = statement_files_with_duplicates.map do |statement_file|
      pending_count = statement_file.pending_transactions.count
      {
        id: statement_file.id,
        filename: statement_file.safe_filename,
        bank_name: statement_file.bank.name,
        account_number: statement_file.bank_account.account_number,
        pending_duplicates_count: pending_count,
        created_at: statement_file.created_at
      }
    end

    render json: {
      has_duplicates: duplicates_data.any?,
      statement_files: duplicates_data
    }
  end

  def process_duplicates
    statement_file_id = params[:statement_file_id]
    selected_transaction_ids = params[:selected_transaction_ids] || []

    result = Transactions::ProcessDuplicatesService.call(
      current_user,
      statement_file_id,
      selected_transaction_ids
    )

    if result.success?
      render json: {
        success: true,
        message: "Duplicates processed successfully",
        processed_count: result.payload[:processed_count]
      }
    else
      render json: {
        success: false,
        error: result.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end

  def get_duplicates
    statement_file_id = params[:statement_file_id]
    statement_file = current_user.statement_files.find(statement_file_id)

    # Get pending transactions for this statement file
    pending_transactions = statement_file.pending_transactions.includes(:user, :bank_account, :category)

    # Group by duplicate groups (same user, bank_account, date, amount)
    duplicate_groups = pending_transactions.group_by do |pt|
      [ pt.user_id, pt.bank_account_id, pt.date, pt.amount ]
    end

    # Format the data for the frontend
    duplicates_data = duplicate_groups.map do |key, transactions|
      {
        group_key: key.join("-"),
        transactions: transactions.map do |pt|
          {
            id: pt.id,
            source: pt.source,
            date: pt.date.strftime("%Y-%m-%d"),
            description: pt.description,
            amount: pt.amount.to_f,
            transaction_type: pt.transaction_type,
            category_name: pt.category&.name || "Sin categor\u00EDa"
          }
        end
      }
    end

    render json: {
      statement_file: {
        id: statement_file.id,
        filename: statement_file.safe_filename,
        bank_name: statement_file.bank.name,
        account_number: statement_file.bank_account.account_number
      },
      duplicates: duplicates_data
    }
  end

  def destroy
    transaction = current_user.transactions.find(params[:id])

    # Only allow deletion of manual transactions
    if transaction.source != "manual"
      redirect_to transactions_path, alert: "Only manual transactions can be deleted"
      return
    end

    if transaction.destroy
      redirect_to transactions_path, notice: "Transaction deleted successfully"
    else
      redirect_to transactions_path, alert: "Failed to delete transaction"
    end
  end

  private

  def request_params
    params.permit(:bank_account_id, :statement_file_id, :transaction_type, :from_date, :to_date, :sort, :direction, :search, :page)
  end

  def transaction_params
    permitted = params.require(:transaction).permit(
      :bank_account_id,
      :date,
      :description,
      :amount,
      :transaction_type,
      :merchant,
      :reference,
      :category_id,
      :transfer_account_id,
      saving_ids: [],
      debt_ids: []
    )

    # Sanitize money fields by removing commas
    permitted[:amount] = sanitize_money_field(permitted[:amount]) if permitted[:amount].present?

    permitted
  end

  def sanitize_money_field(value)
    value.to_s.delete(",")
  end

  def load_transaction_data(payload)
    @transactions = payload[:transactions]
    @filtered_transactions = payload[:filtered_transactions]
    @statement_file = payload[:statement_file]
    @current_sort = payload[:current_sort]
    @current_direction = payload[:current_direction]
  end

  def handle_pagination
    # Ensure we have an ActiveRecord::Relation to paginate
    unless @transactions.is_a?(ActiveRecord::Relation)
      Rails.logger.error "Pagination error: @transactions is not an ActiveRecord::Relation"
      @transactions = current_user.transactions.none
    end

    # Determine page number with simplified logic
    page = calculate_page_number

    # Use Pagy for pagination with error handling
    begin
      @pagy, @transactions = pagy(@transactions, items: 20, page: page)
    rescue Pagy::OverflowError
      # If page is beyond total pages, reset to page 1
      @pagy, @transactions = pagy(@transactions, items: 20, page: 1)
    rescue StandardError => e
      # Log error for debugging
      Rails.logger.error "Pagination error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Re-raise in development to surface issues during testing
      raise e if Rails.env.development?

      # In production, provide user feedback and graceful fallback
      flash.now[:alert] = "Error loading transactions. Please try again."
      @pagy, @transactions = pagy(@transactions.none, items: 20, page: 1)
    end
  end

  def calculate_page_number
    # Reset to first page ONLY when filters change (not when just changing page)
    # Sorting and pagination changes should preserve other filters
    # Only reset to page 1 if filters changed AND it's not an AJAX/XHR request
    if !request.xhr? && fresh_filter_request?
      1  # Reset to page 1 when filters change
    else
      # Honor page parameter for normal pagination navigation
      parse_page_param
    end
  end

  def parse_page_param
    return 1 unless params[:page].present?

    Integer(params[:page])
  rescue ArgumentError, TypeError
    1
  end

  def load_dropdown_data
    @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)
    @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)

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

    # Load active savings and debts for manual linking (no filtering, user has full control)
    @savings = current_user.savings.active.order(:name)
    @debts = current_user.debts.active.order(:name)
  end

  def handle_ajax_request
    # Handle AJAX requests for infinite scrolling
    if request.xhr? && params[:page].present?
      page_offset = (@pagy.page - 1) * 20

      # Return HTML partial for infinite scrolling
      render partial: "transactions/transaction_rows", locals: {
        transactions: @transactions,
        page_offset: page_offset
      }
    # Handle Turbo Frame requests for search/filter updates
    elsif turbo_frame_request_id == "transactions-results"
      render partial: "transactions/results", locals: {
        transactions: @transactions,
        pagy: @pagy,
        current_sort: @current_sort,
        current_direction: @current_direction
      }
    end
  end

  def calculate_stats
    filtered = @filtered_transactions || current_user.transactions.none

    income_total = filtered.where(transaction_type: "income").sum(:amount)
    expenses_total = filtered.where(transaction_type: ["fixed_expense", "variable_expense"]).sum(:amount)
    equity_total = income_total + expenses_total

    income_count = filtered.where(transaction_type: "income").count
    fixed_expense_count = filtered.where(transaction_type: "fixed_expense").count
    variable_expense_count = filtered.where(transaction_type: "variable_expense").count

    category_count = begin
      filtered.joins(:category).distinct.count(:category_id) +
      (filtered.where(category_id: nil).count > 0 ? 1 : 0)
    rescue
      0
    end

    # Use filtered_transactions count if @pagy is not set (e.g., for JSON requests)
    total_count = @pagy ? @pagy.count : (filtered.respond_to?(:count) ? filtered.count : 0)

    @stats = {
      total_transactions: total_count,
      income_total: income_total.to_f,
      expenses_total: expenses_total.to_f,
      equity_total: equity_total.to_f,
      income_count: income_count,
      fixed_expense_count: fixed_expense_count,
      variable_expense_count: variable_expense_count,
      category_count: category_count
    }
  end

  def fresh_filter_request?
    # Check if filter parameters have changed (excluding page, sort, direction, search)
    # Only reset pagination when actual filters change, not when navigating pages

    # Get current filter parameters (excluding pagination/sorting params)
    current_filters = {
      "from_date" => params[:from_date],
      "to_date" => params[:to_date],
      "bank_account_id" => params[:bank_account_id],
      "statement_file_id" => params[:statement_file_id],
      "transaction_type" => params[:transaction_type],
      "search" => params[:search]
    }

    # Get previous filter parameters from session
    previous_filters = session[:previous_transaction_filters] || {}

    # Check if any filter parameters have changed
    filters_changed = current_filters != previous_filters

    # Always store current filters for next comparison
    session[:previous_transaction_filters] = current_filters

    # Return true if filters changed (requiring pagination reset)
    filters_changed
  end
end
