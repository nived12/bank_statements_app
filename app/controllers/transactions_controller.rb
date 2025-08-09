# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  def index
    @bank_accounts = BankAccount.order(:bank_name, :account_number)
    @q_account_id = params[:bank_account_id]
    scope = Transaction.order(date: :desc)
    scope = scope.where(bank_account_id: @q_account_id) if @q_account_id.present?
    @transactions = scope.limit(500)
  end
end
