# frozen_string_literal: true

json.data do
  json.savings(@savings) do |saving|
    json.partial!("api/v1/shared/saving", saving: saving)
  end
end

# Pagination metadata
json.meta do
  json.pagination do
    json.partial!("api/v1/shared/pagination", pagy: @pagy)
  end
end
