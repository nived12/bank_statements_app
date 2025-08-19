class StatementFilesController < ApplicationController
  def index
    @statement_files = current_user.statement_files.includes(:bank_account, :transactions)
                                  .order(created_at: :desc)
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
