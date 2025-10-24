json.array! @statement_files do |statement_file|
  json.id statement_file.id
  json.cutoff_date statement_file.cutoff_date
end
