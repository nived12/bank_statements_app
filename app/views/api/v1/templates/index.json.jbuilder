# frozen_string_literal: true

json.data do
  json.savings(@savings) do |template|
    json.key template[:key]
    json.type "saving"
    json.name FinancialTemplate.name_for("saving", template[:key])
    json.description FinancialTemplate.description_for("saving", template[:key])
    json.icon template[:icon]
    json.color template[:color]
    json.suggested_target_amount template[:suggested_target_amount]
    json.calculation_settings template[:calculation_settings]
    json.category_name template[:category_name]
  end

  json.debts(@debts) do |template|
    json.key template[:key]
    json.type "debt"
    json.name FinancialTemplate.name_for("debt", template[:key])
    json.description FinancialTemplate.description_for("debt", template[:key])
    json.icon template[:icon]
    json.color template[:color]
    json.suggested_interest_rate template[:suggested_interest_rate]
    json.calculation_settings template[:calculation_settings]
    json.category_name template[:category_name]
  end
end
