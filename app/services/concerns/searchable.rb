# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  module ClassMethods
    def search_by(searchable_params)
      results = all

      searchable_params.keys.each_with_index do |key, i|
        value = searchable_params[key]
        next if value.blank?

        results =
          if i.zero?
            public_send(:"search_by_#{key}", searchable_params[key])
          else
            results.or(public_send(:"search_by_#{key}", value))
          end
      end

      results
    end
  end
end
