class StatementFilesController < ApplicationController
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
    @statement_file = current_user.statement_files.new(statement_file_params)

    if @statement_file.save
      StatementIngestJob.perform_later(@statement_file.id)

      respond_to do |format|
        format.html {
 redirect_to statement_file_path(@statement_file), notice: t("statement_files.uploaded_successfully") }
        format.turbo_stream {
 redirect_to statement_file_path(@statement_file), notice: t("statement_files.uploaded_successfully") }
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
      permitted_params = params.require(:statement_file).permit(
        :bank_account_id, :file, :processing_strategy,
        :cutoff_date
      )

      # Validate processing_strategy: use param if valid, else user's default
      valid_strategies = %w[parser_only text_with_ai vision_ai]
      unless valid_strategies.include?(permitted_params[:processing_strategy])
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
    rescue ActionController::ParameterMissing => e
      Rails.logger.error "Parameter missing: #{e.message}"
      Rails.logger.error "Available params: #{params.keys}"
      Rails.logger.error "Raw params: #{params.inspect}"

      # Try to extract parameters manually if they exist
      if params[:statement_file].present?
        manual_params = params[:statement_file].permit(:bank_account_id, :file, :processing_strategy, :cutoff_date)
        valid_strategies = %w[parser_only text_with_ai vision_ai]
        unless valid_strategies.include?(manual_params[:processing_strategy])
          manual_params[:processing_strategy] = current_user.user_settings.processing_strategy
        end
        manual_params
      else
        # Fallback to empty params with user's default strategy
        { bank_account_id: nil, file: nil, processing_strategy: current_user.user_settings.processing_strategy,
cutoff_date: nil }
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
