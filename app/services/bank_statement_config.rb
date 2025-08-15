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

  def get_patterns(bank_name, pattern_type)
    bank = bank_config(bank_name)
    return [] unless bank

    patterns = []
    bank["variations"].each do |variation|
      patterns.concat(Array(variation[pattern_type])) if variation[pattern_type]
    end
    patterns.uniq
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
    config_path = Rails.root.join("config", "bank_statement_patterns.yml")
    @config = YAML.load_file(config_path)
  rescue Errno::ENOENT
    Rails.logger.error "Bank statement patterns config file not found: #{config_path}"
    @config = { "banks" => {}, "global" => {} }
  rescue Psych::SyntaxError => e
    Rails.logger.error "Invalid YAML in bank statement patterns config: #{e.message}"
    @config = { "banks" => {}, "global" => {} }
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
