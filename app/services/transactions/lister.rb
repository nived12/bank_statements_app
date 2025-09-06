# frozen_string_literal: true

##
# Transactions::Lister
# Service for listing and filtering transactions with sorting capabilities
#
class Transactions::Lister < ApplicationService
  include Sortable

  def initialize(user, filter_params = {})
    super()
    @user = user
    @filter_params = filter_params
    @statement_file = nil
  end

  def call
    load_transactions
    return failure if has_errors?

    success(build_response)
  end

  private

  attr_reader :user, :filter_params, :statement_file

  def load_transactions
    # Start with base scope including necessary associations
    @transactions = user.transactions.includes(:bank_account, :statement_file, :category)

    # Apply filters using the Filterable concern
    @transactions = @transactions.filter_by(filtering_params)

    # Handle statement file special logic
    handle_statement_file_filter

    # Apply sorting
    @transactions = apply_sorting(@transactions, sort_params)

    # Store filtered scope for stats calculations
    @filtered_transactions = @transactions
  rescue => e
    errors.add(:base, :loading_failed, message: "Failed to load transactions: #{e.message}")
  end

  def handle_statement_file_filter
    return unless filter_params[:statement_file_id].present?

    @statement_file = user.statement_files.find_by(id: filter_params[:statement_file_id])

    unless @statement_file
      errors.add(:base, :statement_file_not_found, message: "Statement file not found")
      return
    end

    # Automatically include bank account filter when statement file is selected
    unless filter_params[:bank_account_id].present?
      @transactions = @transactions.where(bank_account_id: @statement_file.bank_account_id)
    end
  end

  def filtering_params
    # Map controller params to filter scope parameters
    {
      bank_account_id: filter_params[:bank_account_id],
      statement_file_id: filter_params[:statement_file_id],
      transaction_type: filter_params[:transaction_type],
      from_date: filter_params[:from_date],
      to_date: filter_params[:to_date]
    }.compact
  end

  def sort_params
    {
      sort: filter_params[:sort] || "date",
      direction: filter_params[:direction] || "desc"
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
