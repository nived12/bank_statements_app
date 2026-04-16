# frozen_string_literal: true

json.data do
  json.banks(@banks) do |bank|
    json.id(bank.id)
    json.code(bank.code)
    json.name(bank.name)
    json.logo_url(bank.logo_url)
    json.supported_type(bank.supported_type)
  end
end
