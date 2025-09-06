# app/services/concerns/merchant_extraction.rb
module MerchantExtraction
  extend ActiveSupport::Concern

  MERCHANT_MAPPINGS = {
    "starbucks" => "STARBUCKS",
    "bestbuy" => "BESTBUY",
    "netflix" => "NETFLIX",
    "amazon" => "AMAZON",
    "google" => "GOOGLE",
    "playtomic" => "PLAYTOMIC",
    "melimas" => "MELIMAS",
    "viva aerobus" => "VIVA AEROBUS",
    "sria finanzas" => "SRIA FINANZAS",
    "conekta" => "CONEKTA",
    "parco" => "PARCO",
    "six premier" => "SIX PREMIER",
    "heb" => "HEB",
    "tesla" => "TESLA",
    "home depot" => "HOME DEPOT",
    "ticketmaster" => "TICKETMASTER",
    "ross" => "ROSS STORES",
    "kfc" => "KFC",
    "arco" => "ARCO",
    "walmart" => "WALMART",
    "wm supercenter" => "WALMART"
  }.freeze

  private

  def extract_merchant(description)
    return description if description.blank?

    description_lower = description.downcase

    # Check for exact matches first
    MERCHANT_MAPPINGS.each do |pattern, merchant_name|
      return merchant_name if description_lower.include?(pattern)
    end

    # Return the original description if no match found
    description
  end
end
