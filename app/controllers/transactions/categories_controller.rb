class Transactions::CategoriesController < ApplicationController
  before_action :set_transaction

  def update
    result = Transactions::Updater.call(
      @transaction.id,
      { category_id: params[:category_id] }
    )

    if result.success?
      @transaction = result.payload
      @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true, category_id: @transaction.category_id } }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.json { render json: { error: result.errors.full_messages.join(", ") }, status: :unprocessable_content }
      end
    end
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:transaction_id])
  end
end
