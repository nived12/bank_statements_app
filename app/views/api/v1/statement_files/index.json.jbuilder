# frozen_string_literal: true

json.data do
  json.statement_files(@statement_files) do |statement_file|
    json.partial!("api/v1/shared/statement_file", statement_file: statement_file)
  end
end

json.meta do
  json.pagination do
    json.partial!("api/v1/shared/pagination", pagy: @pagy)
  end
end
