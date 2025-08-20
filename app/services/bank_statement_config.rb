# Bank Statement Configuration Service
# Loads and manages bank-specific parsing patterns from configuration files
class BankStatementConfig
  include Singleton

  attr_reader :config

  def initialize
    load_config
  end

  def self.instance
    @instance ||= new
  end

  def bank_config(bank_name)
    bank_name = normalize_bank_name(bank_name)
    @config["banks"][bank_name]
  end

  def get_parser_for_bank_account(bank_account)
    return "generic" unless bank_account.supported_for_parsing?

    # Use account_type to determine parser for BBVA
    if bank_account.bank.code == "bbva"
      case bank_account.account_type
      when "debit"
        "bbva_savings"      # Debit accounts use savings parser
      when "credit"
        "bbva_credit_card"  # Credit accounts use credit card parser
      else
        "bbva_credit_card"  # Default fallback
      end
    else
      bank_account.bank.code
    end
  end

  def get_patterns(bank_name, pattern_type)
    bank = bank_config(bank_name)
    return [] unless bank

    # For banks with multiple variations, try to intelligently select the best matching variation
    if bank["variations"] && bank["variations"].length > 1
      best_variation = select_best_variation(bank["variations"], pattern_type)
      if best_variation && best_variation[pattern_type]
        return Array(best_variation[pattern_type])
      end
    end

    # For BBVA, always use the first variation (standard) to ensure consistent behavior
    if bank_name == "bbva" && bank["variations"] && bank["variations"].length > 1
      first_variation = bank["variations"].first
      if first_variation && first_variation[pattern_type]
        return Array(first_variation[pattern_type])
      end
    end

    # Fallback to combining all variations (original behavior)
    patterns = []
    bank["variations"].each do |variation|
      patterns.concat(Array(variation[pattern_type])) if variation[pattern_type]
    end
    patterns.uniq
  end

  def select_best_variation(variations, pattern_type)
    # Look for variation-specific indicators that suggest which variation to use
    # This works for any bank, not just BBVA

    # For BBVA, prioritize credit card variation if credit card indicators are present
    if variations.any? { |v| v["name"] == "credit_card" }
      credit_card_variation = variations.find { |v| v["name"] == "credit_card" }
      if credit_card_variation && has_credit_card_indicators?(credit_card_variation)
        return credit_card_variation
      end
    end



    # Look for variation-specific identifiers that are unique to one variation
    variations.each do |variation|
      if variation["table_identifiers"]
        variation["table_identifiers"].each do |identifier|
          # Check if this variation has unique identifiers that distinguish it from others
          if is_distinctive_identifier?(identifier, variations)
            return variation
          end
        end
      end
    end

    # If no distinctive variation found, return the first one
    variations.first
  end

  def has_credit_card_indicators?(variation)
    # Check if this variation has credit card specific indicators
    return false unless variation["table_identifiers"]

    credit_card_indicators = [
      "Movimientos Efectuados",
      "Tarjeta Titular",
      "IMPORTE CARGOS",
      "IMPORTE ABONOS"
    ]

    variation["table_identifiers"].any? do |identifier|
      credit_card_indicators.any? { |indicator| identifier.include?(indicator) }
    end
  end

  def is_distinctive_identifier?(identifier, variations)
    # Check if this identifier is unique to one variation
    # This helps distinguish between different statement formats for the same bank

    identifier_count = 0
    variations.each do |variation|
      if variation["table_identifiers"]
        variation["table_identifiers"].each do |var_identifier|
          if var_identifier.include?(identifier) || identifier.include?(var_identifier)
            identifier_count += 1
          end
        end
      end
    end

    # If this identifier appears in only one variation, it's distinctive
    identifier_count == 1
  end

  def get_transaction_patterns(bank_name)
    get_patterns(bank_name, "transaction_keywords")
  end

  def get_non_transaction_patterns(bank_name)
    get_patterns(bank_name, "non_transaction_patterns")
  end

  def get_table_identifiers(bank_name)
    get_patterns(bank_name, "table_identifiers")
  end

  def get_date_patterns(bank_name)
    get_patterns(bank_name, "date_patterns")
  end

  def get_amount_columns(bank_name)
    get_patterns(bank_name, "amount_columns")
  end

  def get_transaction_codes(bank_name)
    get_patterns(bank_name, "transaction_codes")
  end

  def get_header_extraction(bank_name)
    bank = bank_config(bank_name)
    return {} unless bank

    headers = {}
    bank["variations"].each do |variation|
      next unless variation["header_extraction"]

      variation["header_extraction"].each do |category, patterns|
        headers[category] ||= []
        headers[category].concat(Array(patterns))
      end
    end
    headers.transform_values(&:uniq)
  end

  def get_financial_extraction(bank_name)
    bank = bank_config(bank_name)
    return {} unless bank

    financial = {}
    bank["variations"].each do |variation|
      next unless variation["financial_extraction"]

      variation["financial_extraction"].each do |category, patterns|
        if category == "statement_type"
          financial[category] = patterns
        else
          financial[category] ||= []
          financial[category].concat(Array(patterns))
        end
      end
    end

    financial["statement_type"] ||= "savings"
    financial
  end

  def get_statement_type(bank_name)
    financial = get_financial_extraction(bank_name)
    financial["statement_type"] || "savings"
  end

  def global_patterns
    @config["global"]
  end

  def supported_banks
    @config["banks"].keys
  end

  def bank_display_name(bank_name)
    bank_name = normalize_bank_name(bank_name)
    bank = bank_config(bank_name)
    bank ? bank["name"] : bank_name
  end

  private

  def load_config
    @config ||= YAML.load_file(Rails.root.join("config", "bank_statement_patterns.yml"))
  rescue Psych::SyntaxError => e
    Rails.logger.error("Error loading bank statement patterns: #{e.message}")
    @config = {}
  rescue => e
    Rails.logger.error("Error loading bank statement patterns: #{e.message}")
    @config = {}
  end

  def normalize_bank_name(bank_name)
    return "generic" unless bank_name
    bank_name.to_s.downcase.strip
  end

  def self.method_missing(method_name, *args, &block)
    if instance.respond_to?(method_name)
      instance.send(method_name, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    instance.respond_to?(method_name) || super
  end
end
