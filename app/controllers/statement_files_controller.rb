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
    Rails.logger.info "DEBUG: Request format: #{request.format}"
    Rails.logger.info "DEBUG: Content type: #{request.content_type}"
    Rails.logger.info "DEBUG: Raw params: #{params.inspect}"
    Rails.logger.info "DEBUG: Statement file params: #{params[:statement_file].inspect}"

    @statement_file = current_user.statement_files.new(statement_file_params)

    if @statement_file.save
      StatementIngestJob.perform_later(@statement_file.id)

      respond_to do |format|
        format.html { redirect_to statement_file_path(@statement_file, locale: I18n.locale), notice: t("statement_files.uploaded_successfully") }
        format.turbo_stream { redirect_to statement_file_path(@statement_file, locale: I18n.locale), notice: t("statement_files.uploaded_successfully") }
      end
    else
      @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)

      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream { render :new, status: :unprocessable_content }
      end
    end
  end

  def show
    @statement_file = current_user.statement_files.find(params[:id])
    @financial_summary = @statement_file.financial_summary

    # Prepare motivational quotes data for the view
    @quotes_data = prepare_motivational_quotes
  end

  def destroy
    @statement_file = current_user.statement_files.find(params[:id])
    statement_name = @statement_file.file.attached? ? @statement_file.file.filename.to_s : t("statement_files.unknown_file")

    ActiveRecord::Base.transaction do
      # Delete transactions that were created from this statement file
      statement_file_transactions = @statement_file.transactions.where(source: :statement_file)
      statement_file_transactions.destroy_all if statement_file_transactions.any?

      # For manual transactions, only remove the statement_file_id reference
      manual_transactions = @statement_file.transactions.where(source: :manual)
      manual_transactions.update_all(statement_file_id: nil) if manual_transactions.any?

      # Now we can safely delete the statement file
      @statement_file.destroy!
    end

    redirect_to statement_files_path, notice: t("statement_files.deleted_successfully", filename: statement_name)
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to statement_files_path, alert: t("statement_files.delete_failed")
  rescue => e
    Rails.logger.error "Error deleting statement file: #{e.message}"
    redirect_to statement_files_path, alert: t("statement_files.delete_failed")
  end

  def retry
    @statement_file = current_user.statement_files.find(params[:id])

    # Only allow retry if status is error
    if @statement_file.error?
      # Reset status and clear error message
      @statement_file.update(
        status: :pending,
        error_message: nil,
        processed_at: nil
      )

      # Restart processing
      StatementIngestJob.perform_later(@statement_file.id)

      render json: { success: true, message: t("statement_files.processing_restarted") }
    else
      render json: { success: false, error: t("statement_files.retry_failed_only") }, status: :unprocessable_content
    end
  end

  private

  def statement_file_params
    begin
      permitted_params = params.require(:statement_file).permit(:bank_account_id, :file, :ai_enabled)
      # Convert ai_enabled string to boolean
      if permitted_params[:ai_enabled].present?
        permitted_params[:ai_enabled] = permitted_params[:ai_enabled] == "true"
      else
        permitted_params[:ai_enabled] = false # Default to false
      end
      permitted_params
    rescue ActionController::ParameterMissing => e
      Rails.logger.error "Parameter missing: #{e.message}"
      Rails.logger.error "Available params: #{params.keys}"
      Rails.logger.error "Raw params: #{params.inspect}"

      # Try to extract parameters manually if they exist
      if params[:statement_file].present?
        manual_params = params[:statement_file].permit(:bank_account_id, :file, :ai_enabled)
        manual_params[:ai_enabled] = manual_params[:ai_enabled] == "true" if manual_params[:ai_enabled].present?
        manual_params
      else
        # Fallback to empty params
        { bank_account_id: nil, file: nil, ai_enabled: false }
      end
    end
  end

  def prepare_motivational_quotes
    [
      { quote: t("quotes.warren_buffett"), author: "Warren Buffett" },
      { quote: t("quotes.benjamin_graham"), author: "Benjamin Graham" },
      { quote: t("quotes.peter_lynch"), author: "Peter Lynch" },
      { quote: t("quotes.john_bogle"), author: "John Bogle" },
      { quote: t("quotes.charlie_munger"), author: "Charlie Munger" },
      { quote: t("quotes.david_ramsey"), author: "David Ramsey" },
      { quote: t("quotes.suze_orman"), author: "Suze Orman" },
      { quote: t("quotes.robert_kiyosaki"), author: "Robert Kiyosaki" },
      { quote: t("quotes.dave_ramsey"), author: "Dave Ramsey" },
      { quote: t("quotes.jim_rohn"), author: "Jim Rohn" }
    ]
  end

end
