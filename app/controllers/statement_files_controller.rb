class StatementFilesController < ApplicationController
  before_action :require_confirmed_user!, only: %i[create retry]
  before_action :check_subscription_access!, only: [:new, :create]
  before_action :set_statement_file, only: [:show, :destroy, :retry, :status]

  VALID_STRATEGIES = %w[parser_only text_with_ai vision_ai].freeze

  def index
    @statement_files = current_user.statement_files.includes(bank_account: :bank, transactions: [])
                                   .order(Arel.sql("COALESCE(cutoff_date, created_at) DESC"))
    @grouped_by_account = @statement_files
                            .group_by(&:bank_account)
                            .reject { |account, _| account.nil? }
                            .sort_by { |account, _| account.display_name.to_s }
    @subscription_allows_upload = subscription_allows_upload?
  end

  def new
    processing_strategy = current_user.user_setting.processing_strategy
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
        current_user.user_setting.processing_strategy = params_hash[:processing_strategy]
        current_user.user_setting.save
      end

      StatementIngestJob.perform_later(@statement_file.id)
      Analytics.capture(distinct_id: current_user.id, event: "statement_uploaded")

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
    @financial_summary = @statement_file.financial_summary

    # Prepare motivational quotes data for the view
    @quotes_data = prepare_motivational_quotes
  end

  def status
    respond_to do |format|
      format.json
      format.any { head :not_acceptable }
    end
  end

  def destroy
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
    # Only allow retry if status is error
    unless @statement_file.error?
      render json: { success: false, error: t("statement_files.retry_failed_only") }, status: :unprocessable_content
      return
    end

    # Prepare update attributes
    update_attrs = { status: :pending, error_message: nil, processed_at: nil }

    # Accept optional password for retry (for password-protected PDFs)
    if params[:file_password].present?
      update_attrs[:file_password] = params[:file_password]
    end

    # Reset status and optionally set password
    @statement_file.update(update_attrs)

    # Restart processing
    StatementIngestJob.perform_later(@statement_file.id)

    render json: { success: true, message: t("statement_files.processing_restarted") }
  end

  private

  def check_subscription_access!
    result = current_user.subscription_access_result
    return if result[:allowed]

    redirect_to statement_files_path, alert: result[:message]
  end

  def set_statement_file
    @statement_file = current_user.statement_files.find(params[:id])
  end

  def statement_file_params
    params.require(:statement_file).permit(
      :bank_account_id, :file, :processing_strategy, :cutoff_date, :file_password
    ).tap do |permitted|
      # Validate processing_strategy: use param if valid, else user's default
      unless VALID_STRATEGIES.include?(permitted[:processing_strategy])
        permitted[:processing_strategy] = current_user.user_setting.processing_strategy
      end

      # Handle cutoff_date: accept both date strings and UTC datetimes
      if permitted[:cutoff_date].present?
        cutoff_value = permitted[:cutoff_date].to_s

        # Check if input contains time information (has 'T' separator or time component)
        # Examples: "2024-01-15" vs "2024-01-15T14:30:45Z" or "2024-01-15 14:30:45"
        has_time_component = cutoff_value.match?(/[T\s]\d{2}:\d{2}/)

        if has_time_component
          # Input has time - parse and use as-is (convert to UTC if needed)
          permitted[:cutoff_date] = Time.zone.parse(cutoff_value).utc
        else
          # Input is just a date - convert to end-of-day UTC
          date = Date.parse(cutoff_value)
          permitted[:cutoff_date] = Time.zone.parse("#{date} 23:59:59").utc
        end
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
      { quote: t("quotes.jim_rohn"), author: "Jim Rohn" },
      { quote: t("quotes.benjamin_franklin"), author: "Benjamin Franklin" },
      { quote: t("quotes.morgan_housel"), author: "Morgan Housel" },
      { quote: t("quotes.george_clason"), author: "George S. Clason" },
      { quote: t("quotes.suze_orman_2"), author: "Suze Orman" },
      { quote: t("quotes.thomas_stanley"), author: "Thomas J. Stanley" }
    ]
  end
end
