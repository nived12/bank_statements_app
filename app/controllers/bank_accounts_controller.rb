# app/controllers/bank_accounts_controller.rb
class BankAccountsController < ApplicationController
  before_action :authenticate!
  before_action :set_bank_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name, :account_number)
  end

  def show; end

  def new
    @bank_account = current_user.bank_accounts.new
    @supported_banks = Bank.active.order(:name)
  end

  def create
    @bank_account = current_user.bank_accounts.new(bank_account_params)
    if @bank_account.save
      redirect_to "/es/bank_accounts", notice: "Bank account added"
    else
      @supported_banks = Bank.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @supported_banks = Bank.active.order(:name)
  end

  def update
    if @bank_account.update(bank_account_params)
      redirect_to "/es/bank_accounts", notice: "Updated"
    else
      @supported_banks = Bank.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bank_account.destroy
    redirect_to "/es/bank_accounts", notice: "Deleted"
  end

  private

  def set_bank_account
    @bank_account = current_user.bank_accounts.find(params[:id])
  end

  def bank_account_params
    params.require(:bank_account).permit(:bank_id, :account_number, :custom_name, :currency, :opening_balance, :opening_balance_date)
  end
end
