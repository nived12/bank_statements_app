namespace :schema do
  desc "Generate schema documentation for models"
  task docs: :environment do
    puts "Generating schema documentation for models..."

    # Get all models more safely
    models = []
    Dir[Rails.root.join("app", "models", "**", "*.rb")].each do |file|
      begin
        require_dependency file
        model_name = File.basename(file, ".rb").classify
        model_class = model_name.constantize
        if model_class < ApplicationRecord && model_class.table_exists?
          models << model_class
        end
      rescue => e
        puts "Warning: Could not load model from #{file}: #{e.message}"
      end
    end

    puts "Found #{models.count} models: #{models.map(&:name).join(', ')}"

    models.each do |model|
      begin
        table_name = model.table_name
        columns = model.connection.columns(table_name)
        indexes = model.connection.indexes(table_name)

        puts "Processing #{model.name} (#{table_name}) with #{columns.count} columns and #{indexes.count} indexes"

        # Generate documentation
        doc = generate_model_doc(model, columns, indexes)

        # Write to a documentation file
        doc_file = "doc/models/#{model.name.underscore}.md"
        FileUtils.mkdir_p(File.dirname(doc_file))
        File.write(doc_file, doc)

        puts "Generated documentation for #{model.name}"
      rescue => e
        puts "Error processing #{model.name}: #{e.message}"
      end
    end

    puts "\nSchema documentation generated in doc/models/"
  end

  private

  def generate_model_doc(model, columns, indexes)
    doc = []
    doc << "# #{model.name}"
    doc << ""
    doc << "## Table: `#{model.table_name}`"
    doc << ""

    # Columns
    doc << "### Columns"
    doc << ""
    doc << "| Column | Type | Nullable | Default | Index |"
    doc << "|--------|------|----------|---------|-------|"

    columns.each do |column|
      index_info = indexes.select { |idx| idx.columns.include?(column.name) }
      index_names = index_info.map(&:name).join(", ")

      doc << "| `#{column.name}` | `#{column.type}` | #{column.null ? 'YES' : 'NO'} | #{column.default || 'NULL'} | #{index_names.presence || '-'} |"
    end

    doc << ""

    # Indexes
    if indexes.any?
      doc << "### Indexes"
      doc << ""
      doc << "| Name | Columns | Unique |"
      doc << "|------|---------|--------|"

      indexes.each do |index|
        doc << "| `#{index.name}` | `#{index.columns.join(', ')}` | #{index.unique ? 'YES' : 'NO'} |"
      end

      doc << ""
    end

    # Associations
    doc << "### Associations"
    doc << ""
    model.reflect_on_all_associations.each do |association|
      doc << "- `#{association.macro} :#{association.name}`"
    end

    doc << ""

    # Validations
    doc << "### Validations"
    doc << ""
    if model.validators.any?
      model.validators.each do |validator|
        doc << "- `#{validator.class.name.demodulize} on #{validator.attributes.join(', ')}`"
      end
    else
      doc << "- No validations defined"
    end

    doc.join("\n")
  end
end
