# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  module ClassMethods
    def filter_by(filtering_params)
      results = all

      filtering_params.each do |key, value|
        next if value.blank? && value != false

        results =
          if value.is_a?(Hash)
            results.public_send(:"filter_by_#{key}", *value.values)
          else
            results.public_send(:"filter_by_#{key}", value)
          end
      end

      results
    end
  end
end
