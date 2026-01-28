class StatementFilesController < ApplicationController
  VALID_STRATEGIES = %w[parser_only text_with_ai vision_ai].freeze

  def index
    @statement_files = current_user.statement_files.includes(:bank_account, :transactions)
                                   .order(Arel.sql("COALESCE(cutoff_date, created_at) DESC"))
  end

  def new
    processing_strategy = current_user.user_settings.processing_strategy
    @statement_file = current_user.statement_files.new(processing_strategy: processing_strategy)
    @bank_accounts = current_user.bank_accounts.joins(:bank).order("banks.name", :account_number)
  end

  def create
    params_hash = statement_file_params
    # Track if processing_strategy was explicitly provided (not defaulted)
    explicit_strategy = VALID_STRATEGIES.include?(params.dig(:statement_file, :processing_strategy))

    @statement_file = current_user.statement_files.new(params_hash)

    if @statement_file.save
      # Save the processing_strategy as user's default preference only if explicitly provided
      if explicit_strategy
        current_user.user_settings.processing_strategy = params_hash[:processing_strategy]
        current_user.user_settings.save
      end

      StatementIngestJob.perform_later(@statement_file.id)

      respond_to do |format|
        format.html do
          redirect_to statement_file_path(@statement_file), notice: t("statement_files.uploaded_successfully")
        end
        format.turbo_stream do
          redirect_to statement_file_path(@statement_file), notice: t("statement_files.uploaded_successfully")
        end
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
    statement_name = if @statement_file.file.attached?
      @statement_file.file.filename.to_s
    else
      t("statement_files.unknown_file")
    end

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
      update_attrs = { status: :pending, error_message: nil, processed_at: nil }

      # Accept optional password for retry (for password-protected PDFs)
      update_attrs[:file_password] = params[:file_password] if params[:file_password].present?

      # Reset status and optionally set password
      @statement_file.update(update_attrs)

      # Restart processing
      StatementIngestJob.perform_later(@statement_file.id)

      render json: { success: true, message: t("statement_files.processing_restarted") }
    else
      render json: { success: false, error: t("statement_files.retry_failed_only") }, status: :unprocessable_content
    end
  end

  private

  def statement_file_params
    permitted_params = params.require(:statement_file).permit(
      :bank_account_id, :file, :processing_strategy,
      :cutoff_date, :file_password
    )

    # Validate processing_strategy: use param if valid, else user's default
    unless VALID_STRATEGIES.include?(permitted_params[:processing_strategy])
      permitted_params[:processing_strategy] = current_user.user_settings.processing_strategy
    end

    # Convert cutoff_date from local date to UTC datetime
    if permitted_params[:cutoff_date].present?
      # Parse the date in user's timezone and convert to UTC
      local_date = Date.parse(permitted_params[:cutoff_date].to_s)
      # Set to end of day in user's timezone, then convert to UTC
      permitted_params[:cutoff_date] = Time.zone.parse("#{local_date} 23:59:59").utc
    end

    permitted_params
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
