class TransactionsController < ApplicationController
  def index
    result = Transactions::Lister.call(current_user, request_params)

    if result.success?
      load_transaction_data(result.payload)
      handle_pagination
      load_dropdown_data
      handle_ajax_request

    else
      redirect_to transactions_path(request_params), alert: "Failed to load transactions"
    end
  end

  def create
    result = Transactions::CreateService.call(transaction_params)

    if result.success?
      redirect_to transactions_path, notice: "Transaction created successfully"
    else
      redirect_to transactions_path, alert: "Failed to create transaction: #{result.errors.full_messages.join(", ")}"
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
      redirect_to transactions_path, alert: "Failed to update transaction: #{result.errors.full_messages.join(", ")}"
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
      goal_ids: []
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
    # Reset to first page when filters change (only for non-AJAX requests)
    # Sorting changes should preserve pagination and filters
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
      @pagy, @transactions = pagy(@transactions, items: 20, page: page)
    rescue Pagy::OverflowError
      # If page is beyond total pages, reset to page 1
      @pagy, @transactions = pagy(@transactions, items: 20, page: 1)
    end
  end

  def load_dropdown_data
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

    # Load active goals for manual linking (no filtering, user has full control)
    @goals = current_user.goals.active.order(:name)
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
end
