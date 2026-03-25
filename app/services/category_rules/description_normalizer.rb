module CategoryRules
  class DescriptionNormalizer
    def self.call(description)
      return "" if description.blank?

      description.downcase.strip.gsub(/\s+/, " ").gsub(/\d{4,}\z/, "").gsub(/\s*#\S+\z/, "").strip
    end
  end
end
