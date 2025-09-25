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
      # Get the AI processing preference from the form
      # Checkbox only sends value when checked, so we default to false if not present
      ai_enabled = params.dig(:statement_file, :ai_enabled) == "true"

      # Store the AI preference in the database
      @statement_file.update(ai_enabled: ai_enabled)

      StatementIngestJob.perform_later(@statement_file.id)
      redirect_to statement_file_path(@statement_file, locale: I18n.locale), notice: t("statement_files.uploaded_successfully")
    else
      @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)
      render :new, status: :unprocessable_content
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

    if @statement_file.destroy
      redirect_to statement_files_path, notice: t("statement_files.deleted_successfully", filename: statement_name)
    else
      redirect_to statement_files_path, alert: t("statement_files.delete_failed")
    end
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
    params.require(:statement_file).permit(:bank_account_id, :file, :ai_enabled)
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
