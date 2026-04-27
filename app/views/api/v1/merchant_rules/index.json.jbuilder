# frozen_string_literal: true

json.data do
  json.array!(@rules) do |rule|
    json.partial!("merchant_rule", rule: rule)
  end
end

json.meta do
  json.partial!("api/v1/shared/pagination", pagy: @pagy)
end
