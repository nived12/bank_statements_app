class BankAccounts::StatementFilesController < ApplicationController
  # GET /bank_accounts/:bank_account_id/statement_files
  def index
    @bank_account = current_user.bank_accounts.find(params[:bank_account_id])
    @statement_files = @bank_account.statement_files

    # Handle sorting
    if params[:sort] && params[:sort][:cutoff_date]
      sort_direction = params[:sort][:cutoff_date].to_sym
      @statement_files = @statement_files.by_cutoff_date(sort_direction)
    else
      @statement_files = @statement_files.by_cutoff_date(:desc)
    end

    respond_to do |format|
      format.json
    end
  end
end
