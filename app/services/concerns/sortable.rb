# frozen_string_literal: true

##
# Sortable
# Generic concern for handling sorting logic in models
#
module Sortable
  extend ActiveSupport::Concern

  module ClassMethods
    ##
    # Apply sorting to a scope based on permitted sort parameters
    #
    # @param permitted_sort_params [Hash] hash of permitted sort fields and their default directions
    # @param raw_sort_params [ActionController::Parameters, Hash] raw parameters from request
    # @return [ActiveRecord::Relation] the sorted scope
    #
    # Example usage:
    #   Transaction.order_by(
    #     { date: 'desc', amount: 'asc', description: 'asc' },
    #     params[:sort]
    #   )
    #
    def order_by(permitted_sort_params, raw_sort_params = nil)
      results = all

      sorting_params =
        if raw_sort_params.present?
          # Handle both ActionController::Parameters and Hash
          raw_params = raw_sort_params.respond_to?(:to_unsafe_h) ? raw_sort_params.to_unsafe_h : raw_sort_params
          # Use the values from raw_params, but only for keys that are permitted
          raw_params.symbolize_keys.slice(*permitted_sort_params.keys)
        else
          permitted_sort_params
        end

      sorting_params.each do |key, value|
        direction = value.to_s.casecmp("desc").zero? ? :desc : :asc
        results = results.public_send(:"sort_by_#{key}", direction) if respond_to?(:"sort_by_#{key}")
      end

      results
    end
  end
end
