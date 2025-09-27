# app/controllers/bank_accounts_controller.rb
class BankAccountsController < ApplicationController
  before_action :authenticate!
  before_action :set_bank_account, only: [ :show, :edit, :update, :destroy ]
  before_action :set_supported_banks, only: [ :new, :create, :edit, :update ]

  def index
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name, :account_number)
    
    # Mobile-specific data preparation
    if mobile_request?
      prepare_mobile_data
    end
  end

  def show; end

  def new
    @bank_account = current_user.bank_accounts.new
  end

  def create
    @bank_account = current_user.bank_accounts.new(bank_account_params)
    if @bank_account.save
      redirect_to bank_accounts_path, notice: t("bank_accounts.added_successfully")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @bank_account.update(bank_account_params)
      redirect_to bank_accounts_path, notice: t("bank_accounts.updated_successfully")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @bank_account.destroy
    redirect_to bank_accounts_path, notice: t("bank_accounts.deleted_successfully")
  end

  private

  def set_supported_banks
    @supported_banks = Bank.active.order(
      Arel.sql("CASE WHEN code = 'generic' THEN 1 ELSE 0 END"),
      :name
    )
  end

  def set_bank_account
    @bank_account = current_user.bank_accounts.find(params[:id])
  end

  def bank_account_params
    params.require(:bank_account).permit(:bank_id, :account_number, :custom_name, :currency, :opening_balance, :opening_balance_date, :account_type)
  end

  def prepare_mobile_data
    # Mobile-optimized data structure for better performance
    @mobile_bank_accounts_data = {
      accounts: @bank_accounts.map do |account|
        {
          id: account.id,
          display_name: account.display_name,
          bank_name: account.bank_display_name,
          account_number: account.account_number,
          currency: account.currency,
          opening_balance: account.opening_balance,
          opening_balance_date: account.opening_balance_date,
          account_type: account.account_type,
          supported_for_parsing: account.supported_for_parsing?,
          statement_files_count: account.statement_files.count,
          transactions_count: account.transactions.count,
          effective_balance: account.effective_balance || 0
        }
      end,
      total_accounts: @bank_accounts.count,
      total_balance: @bank_accounts.sum { |account| account.effective_balance || 0 },
      supported_accounts: @bank_accounts.count(&:supported_for_parsing?),
      generic_accounts: @bank_accounts.count { |account| !account.supported_for_parsing? }
    }
  end
end
