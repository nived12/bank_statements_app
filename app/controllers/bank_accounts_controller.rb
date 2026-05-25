# app/controllers/bank_accounts_controller.rb
class BankAccountsController < ApplicationController
  before_action :authenticate!
  before_action :require_confirmed_user!, only: %i[create update destroy]
  before_action :set_bank_account, only: [ :show, :edit, :update, :destroy ]
  before_action :set_supported_banks, only: [ :show, :new, :create, :edit, :update ]

  def index
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name, :account_number)

    respond_to do |format|
      format.html
      format.json
    end
  end

  def show
    @recent_statement_files = @bank_account.statement_files.order(created_at: :desc).limit(3)
  end

  def new
    @bank_account = current_user.bank_accounts.new
  end

  def create
    @bank_account = current_user.bank_accounts.new(bank_account_params)
    if @bank_account.save
      Analytics.capture(distinct_id: current_user.id, event: "bank_account_created")
      redirect_to bank_account_path(@bank_account), notice: t("bank_accounts.added_successfully")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @bank_account.update(bank_account_params)
      redirect_to bank_account_path(@bank_account), notice: t("bank_accounts.updated_successfully")
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
    @supported_banks = Bank.order(
      Arel.sql("CASE WHEN code = 'generic' THEN 1 ELSE 0 END"),
      :name
    )
  end

  def set_bank_account
    @bank_account = current_user.bank_accounts.find(params[:id])
  end

  def bank_account_params
    params.require(:bank_account).permit(
      :bank_id, :account_number, :custom_name, :currency, :opening_balance,
      :opening_balance_date, :account_type
    )
  end
end
