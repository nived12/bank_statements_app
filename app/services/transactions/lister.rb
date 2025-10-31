# frozen_string_literal: true

##
# Transactions::Lister
# Service for listing and filtering transactions with sorting capabilities
#
class Transactions::Lister < ApplicationService
  def initialize(user, params = {})
    super()
    @user = user
    @params = params
    @statement_file = nil
  end

  def call
    load_transactions
    return failure if has_errors?

    success(build_response)
  end

  private

  attr_reader :user, :params, :statement_file

  def load_transactions
    # Start with base scope including necessary associations
    @transactions = user.transactions.includes(:bank_account, :statement_file, :category, linked_transfer: :bank_account)

    # Apply filters using the Filterable concern
    @transactions = @transactions.filter_by(filtering_params)

    # Apply search using the model's Searchable concern
    @transactions = @transactions.search_by(searching_params)

    # Handle statement file special logic
    handle_statement_file_filter

    # Apply sorting using the model's Sortable concern
    @transactions = @transactions.order_by(permitted_sort_params, build_sort_params)

    # Store filtered scope for stats calculations
    @filtered_transactions = @transactions
  rescue => e
    errors.add(:base, :loading_failed, message: "Failed to load transactions: #{e.message}")
  end

  def handle_statement_file_filter
    return unless params[:statement_file_id].present?

    @statement_file = user.statement_files.find_by(id: params[:statement_file_id])

    unless @statement_file
      errors.add(:base, :statement_file_not_found, message: "Statement file not found")
      return
    end

    # Automatically include bank account filter when statement file is selected
    unless params[:bank_account_id].present?
      @transactions = @transactions.where(bank_account_id: @statement_file.bank_account_id)
    end
  end

  def filtering_params
    # Map controller params to filter scope parameters
    {
      bank_account_id: params[:bank_account_id],
      statement_file_id: params[:statement_file_id],
      transaction_type: params[:transaction_type],
      from_date: params[:from_date],
      to_date: params[:to_date]
    }.compact
  end

  def searching_params
    # Map controller params to search scope parameters
    {
      description: params[:search]
    }.compact
  end

  def permitted_sort_params
    {
      date: "desc",
      amount: "desc",
      description: "asc",
      transaction_type: "asc",
      merchant: "asc",
      category: "asc",
      bank_account: "asc"
    }
  end

  def build_sort_params
    sort_field = params[:sort] || "date"
    direction = params[:direction] || "desc"

    # Only include valid sort fields
    if permitted_sort_params.key?(sort_field.to_sym)
      { sort_field => direction }
    else
      # Fallback to default sort if invalid field provided
      { "date" => "desc" }
    end
  end

  def sort_params
    {
      sort: params[:sort] || "date",
      direction: params[:direction] || "desc"
    }
  end

  def build_response
    {
      transactions: @transactions,
      filtered_transactions: @filtered_transactions,
      statement_file: @statement_file,
      current_sort: sort_params[:sort],
      current_direction: sort_params[:direction]
    }
  end
end
