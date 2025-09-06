# frozen_string_literal: true

##
# Sortable
# Concern for handling sorting logic in services
#
module Sortable
  extend ActiveSupport::Concern

  private

  ##
  # Apply sorting to a scope based on sort parameters
  #
  # @param scope [ActiveRecord::Relation] the scope to sort
  # @param sort_params [Hash] hash containing :sort and :direction keys
  # @return [ActiveRecord::Relation] the sorted scope
  #
  def apply_sorting(scope, sort_params)
    sort_field = sort_params[:sort] || "date"
    direction = sort_params[:direction] || "desc"

    case sort_field
    when "date"
      scope.order(date: direction.to_sym)
    when "amount"
      scope.order(amount: direction.to_sym)
    when "description"
      scope.order(description: direction.to_sym)
    when "transaction_type"
      scope.order(transaction_type: direction.to_sym)
    when "category"
      scope.joins(:category).order('categories.name': direction.to_sym)
    when "merchant"
      scope.order(merchant: direction.to_sym)
    when "bank_account"
      scope.joins(bank_account: :bank).order('banks.name': direction.to_sym)
    else
      scope.order(date: :desc) # Default fallback
    end
  end
end
