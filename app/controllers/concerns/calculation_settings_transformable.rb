# frozen_string_literal: true

##
# CalculationSettingsTransformable
# Shared concern for transforming calculation settings params from individual fields to a hash
#
module CalculationSettingsTransformable
  extend ActiveSupport::Concern

  private

  ##
  # Transform individual calculation settings fields into a hash
  #
  # @param params [ActionController::Parameters] The params hash to transform
  # @return [void] Modifies params in place
  #
  def transform_calculation_settings!(params)
    settings = {}
    %w[income expense transfer_in transfer_out].each do |type|
      key = "calculation_settings_#{type}"
      settings[type] = params.delete(key.to_sym) if params[key.to_sym].present?
    end
    params[:calculation_settings] = settings if settings.any?
  end

  ##
  # Clean money fields by removing commas and spaces
  #
  # @param params [ActionController::Parameters] The params hash
  # @param fields [Array<Symbol>] List of money field names to clean
  # @return [void] Modifies params in place
  #
  def sanitize_money_fields!(params, *fields)
    fields.each do |field|
      params[field] = params[field].to_s.gsub(/[,\s]/, "") if params[field].present?
    end
  end
end
