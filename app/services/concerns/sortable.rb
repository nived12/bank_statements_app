# frozen_string_literal: true

##
# Sortable
# Generic concern for handling sorting logic in models
#
module Sortable
  extend ActiveSupport::Concern

  module ClassMethods
    ##
    # Apply sorting to a scope based on sort parameters
    #
    # @param field [Symbol, String] the field to sort by
    # @param direction [Symbol, String] the sort direction (:asc or :desc)
    # @return [ActiveRecord::Relation] the sorted scope
    #
    # Example usage:
    #   Transaction.order_by(:date, :desc)
    #   Transaction.order_by(:amount, :asc)
    #
    def order_by(field, direction = :desc)
      return all if field.blank?

      field = field.to_sym
      direction = direction.to_sym

      # Validate direction, fallback to desc if invalid
      direction = :desc unless %i[asc desc].include?(direction)

      # Call the specific sort_by_* scope if it exists, otherwise fallback to date
      if respond_to?(:"sort_by_#{field}")
        public_send(:"sort_by_#{field}", direction)
      elsif respond_to?(:sort_by_date)
        sort_by_date(:desc)
      else
        all
      end
    end
  end
end
