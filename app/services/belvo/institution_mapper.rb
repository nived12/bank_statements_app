class Belvo::InstitutionMapper < ApplicationService
  INSTITUTION_MAP = {
    "bbva_mx_retail" => "bbva",
    "bbva_mx_business" => "bbva",
    "banorte_mx_retail" => "banorte",
    "santander_mx_retail" => "santander",
    "scotiabank_mx_retail" => "scotiabank",
    "banamex_mx_retail" => "banamex",
    "banco_azteca_mx_retail" => "azteca",
    "banregio_mx_retail" => "banregio",
    "nu_mx_retail" => "nu",
    "rappi_mx_retail" => "rappi",
    "hsbc_mx_retail" => "hsbc"
  }.freeze

  def initialize(belvo_institution)
    super()
    @belvo_institution = belvo_institution
  end

  def call
    local_code = INSTITUTION_MAP[@belvo_institution]

    if local_code
      bank = Bank.find_by(code: local_code)
      return success(bank) if bank
    end

    # Create a new Bank record for unmapped institutions
    bank = Bank.find_or_create_by!(code: @belvo_institution) do |b|
      b.name = humanize_institution(@belvo_institution)
      b.active = true
    end
    success(bank)
  rescue ActiveRecord::RecordInvalid => e
    failure("Failed to map institution: #{e.message}")
  end

  private

  def humanize_institution(code)
    code.gsub(/_mx_(retail|business)$/, "")
        .titleize
  end
end
