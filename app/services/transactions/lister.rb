# frozen_string_literal: true

##
# Transactions::Lister
# Service for listing and filtering transactions with sorting capabilities
#
class Transactions::Lister < ApplicationService
  def initialize(params = {})
    super()
    @params = params
    @statement_file = nil
  end

  def call
    load_transactions
    return failure if has_errors?

    success(build_response)
  end

  private

  attr_reader :params, :statement_file

  def load_transactions
    @transactions = Current.user.transactions
      .includes(:bank_account, :statement_file, :category, linked_transfer: :bank_account)
      .filter_by(filtering_params)
      .search_by(searching_params)
      .order_by(sort_field, sort_direction)

    handle_statement_file_filter
  rescue => e
    errors.add(:base, :loading_failed, message: "Failed to load transactions: #{e.message}")
  end

  def handle_statement_file_filter
    return unless params[:statement_file_id].present?

    @statement_file = Current.user.statement_files.find_by(id: params[:statement_file_id])
    return errors.add(:base, :statement_file_not_found, message: "Statement file not found") unless @statement_file

    unless params[:bank_account_id].present?
      @transactions = @transactions.where(bank_account_id: @statement_file.bank_account_id)
    end
  end

  def filtering_params
    params.slice(:bank_account_id, :statement_file_id, :transaction_type, :from_date, :to_date).compact
  end

  def searching_params
    { description: params[:search] }.compact
  end

  def sort_field
    params[:sort] || :date
  end

  def sort_direction
    params[:direction] || :desc
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
