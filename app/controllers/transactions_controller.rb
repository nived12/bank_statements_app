class TransactionsController < ApplicationController
  def index
    scope = current_user.transactions.includes(:bank_account, :statement_file).order(date: :desc)
    scope = scope.where(bank_account_id: params[:bank_account_id]) if params[:bank_account_id].present?
    @transactions = scope.limit(500)
    @bank_accounts = current_user.bank_accounts.order(:bank_name, :account_number)
  end

  def update
    transaction = current_user.transactions.find(params[:id])
    if transaction.update(params.require(:transaction).permit(:transaction_type, :category, :sub_category))
      redirect_to "/transactions", notice: "Updated"
    else
      redirect_to "/transactions", alert: "Update failed"
    end
  end
end
