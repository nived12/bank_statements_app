# frozen_string_literal: true

json.data do
  json.partial!("merchant_rule", rule: @rule)
end

json.message(I18n.t("api.merchant_rules.created"))
