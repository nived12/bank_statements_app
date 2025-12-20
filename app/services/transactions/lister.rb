# frozen_string_literal: true

##
# Transactions::Lister
# Service for listing and filtering transactions with sorting capabilities
#
class Transactions::Lister < ApplicationService
  PERMITTED_SORT_FIELDS = Set.new([
    :date, :amount, :description, :transaction_type,
    :merchant, :category, :bank_account
  ]).freeze

  DEFAULT_SORT = { "date" => "desc" }.freeze

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
    @transactions = user.transactions
      .includes(:bank_account, :statement_file, :category, linked_transfer: :bank_account)
      .filter_by(filtering_params)
      .search_by(searching_params)

    handle_statement_file_filter

    @transactions = @transactions.order_by(permitted_sort_params, build_sort_params)
  rescue => e
    errors.add(:base, :loading_failed, message: "Failed to load transactions: #{e.message}")
  end

  def handle_statement_file_filter
    return unless params[:statement_file_id].present?

    @statement_file = user.statement_files.find_by(id: params[:statement_file_id])
    return errors.add(:base, :statement_file_not_found, message: "Statement file not found") unless @statement_file

    @transactions = @transactions.where(bank_account_id: @statement_file.bank_account_id) unless params[:bank_account_id].present?
  end

  def filtering_params
    params.slice(:bank_account_id, :statement_file_id, :transaction_type, :from_date, :to_date).compact
  end

  def searching_params
    { description: params[:search] }.compact
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
    current_sort = params[:sort] || "date"
    current_direction = params[:direction] || "desc"

    PERMITTED_SORT_FIELDS.include?(current_sort.to_sym) ? { current_sort => current_direction } : DEFAULT_SORT
  end

  def build_response
    {
      transactions: @transactions,
      statement_file: @statement_file,
      current_sort: params[:sort] || "date",
      current_direction: params[:direction] || "desc"
    }
  end
end
