class StatementFilesController < ApplicationController
  def new
    @bank_accounts = BankAccount.all
    @statement_file = StatementFile.new
  end

  def create
    @statement_file = StatementFile.new(
      bank_account_id: params[:statement_file][:bank_account_id],
      status: "pending"
    )

    @statement_file.file.attach(params[:statement_file][:file]) if params[:statement_file][:file].present?

    if @statement_file.save
      StatementIngestJob.perform_later(@statement_file.id)
      redirect_to @statement_file, notice: "File uploaded and queued for processing."
    else
      @bank_accounts = BankAccount.all
      flash.now[:alert] = "Upload failed"
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @statement_file = StatementFile.find(params[:id])
  end
end
