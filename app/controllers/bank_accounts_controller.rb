# app/controllers/bank_accounts_controller.rb
class BankAccountsController < ApplicationController
  before_action :authenticate!
  before_action :set_bank_account, only: [ :show, :edit, :update, :destroy ]
  before_action :set_supported_banks, only: [ :new, :create, :edit, :update ]

  def index
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name, :account_number)

    respond_to do |format|
      format.html
      format.json { render json: @bank_accounts.map { |ba|
        {
          id: ba.id,
          bank_display_name: ba.bank_display_name,
          account_number: ba.account_number,
          custom_name: ba.custom_name
        }
      }}
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
end
