class StatementFilesController < ApplicationController
  def new
    @statement_file = current_user.statement_files.new
    @bank_accounts = current_user.bank_accounts.order(:bank_name, :account_number)
  end

  def create
    @statement_file = current_user.statement_files.new(statement_file_params)
    if @statement_file.save
      StatementIngestJob.perform_later(@statement_file.id)
      redirect_to "/statement_files/#{@statement_file.id}", notice: "Uploaded"
    else
      @bank_accounts = current_user.bank_accounts.order(:bank_name, :account_number)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @statement_file = current_user.statement_files.find(params[:id])
  end

  private

  def statement_file_params
    params.require(:statement_file).permit(:bank_account_id, :file)
  end
end
