class StatementFilesController < ApplicationController
  def index
    @statement_files = current_user.statement_files.includes(:bank_account, :transactions)
                                  .order(created_at: :desc)
                                  .page(params[:page])
  end

  def test_data
    user = current_user
    current_month = Date.current.beginning_of_month
    end_of_month = Date.current.end_of_month
    
    transactions = user.transactions.where(date: current_month..end_of_month)
    income = transactions.where(transaction_type: "income").sum(:amount)
    expenses = transactions.where(transaction_type: [ "fixed_expense", "variable_expense" ]).sum(:amount)
    
    render json: {
      user_email: user.email,
      total_transactions: user.transactions.count,
      total_statements: user.statement_files.count,
      current_month_transactions: transactions.count,
      income: income,
      expenses: expenses,
      net: income + expenses
    }
  end

  def new
    @statement_file = current_user.statement_files.new
    @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)
  end

  def create
    @statement_file = current_user.statement_files.new(statement_file_params)
    if @statement_file.save
      StatementIngestJob.perform_later(@statement_file.id)
      redirect_to "/statement_files/#{@statement_file.id}", notice: "Uploaded"
    else
      @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @statement_file = current_user.statement_files.find(params[:id])
  end

  def destroy
    @statement_file = current_user.statement_files.find(params[:id])
    statement_name = @statement_file.file.attached? ? @statement_file.file.filename.to_s : "Unknown File"

    if @statement_file.destroy
      redirect_to "/dashboard?action=deleted&fileName=#{CGI.escape(statement_name)}"
    else
      redirect_to "/statement_files/#{@statement_file.id}"
    end
  end

  def retry
    @statement_file = current_user.statement_files.find(params[:id])

    # Only allow retry if status is error
    if @statement_file.status == "error"
      # Reset status and clear error message
      @statement_file.update(
        status: "pending",
        error_message: nil,
        processed_at: nil
      )

      # Restart processing
      StatementIngestJob.perform_later(@statement_file.id)

      render json: { success: true, message: "Processing restarted successfully" }
    else
      render json: { success: false, error: "Can only retry failed statements" }, status: :unprocessable_entity
    end
  end

  private

  def statement_file_params
    params.require(:statement_file).permit(:bank_account_id, :file)
  end
end
