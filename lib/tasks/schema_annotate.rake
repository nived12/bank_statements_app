namespace :schema do
  desc "Add schema information as comments to model files (like annotate gem)"
  task annotate: :environment do
    puts "Adding schema information to model files..."

    # Get all models more safely
    models = []
    Dir[Rails.root.join("app", "models", "**", "*.rb")].each do |file|
      begin
        require_dependency file
        model_name = File.basename(file, ".rb").classify
        model_class = model_name.constantize
        if model_class < ApplicationRecord && model_class.table_exists?
          models << { file: file, class: model_class }
        end
      rescue => e
        puts "Warning: Could not load model from #{file}: #{e.message}"
      end
    end

    puts "Found #{models.count} models to annotate"

    models.each do |model_info|
      begin
        file_path = model_info[:file]
        model_class = model_info[:class]

        puts "Annotating #{model_class.name} in #{file_path}"

        # Read current file content
        content = File.read(file_path)

        # Generate schema comment
        schema_comment = generate_schema_comment(model_class)

        # Remove existing schema comment if present
        content = remove_existing_schema_comment(content)

        # Add new schema comment at the bottom of the file
        content = add_schema_comment_at_bottom(content, schema_comment)

        # Write back to file
        File.write(file_path, content)

        puts "Annotated #{model_class.name}"
      rescue => e
        puts "Error annotating #{model_info[:class].name}: #{e.message}"
      end
    end

    puts "\nSchema annotation completed!"
  end

  private

  def generate_schema_comment(model)
    table_name = model.table_name
    columns = model.connection.columns(table_name)
    indexes = model.connection.indexes(table_name)

    comment = []
    comment << "# == Schema Information"
    comment << "#"
    comment << "# Table name: #{table_name}"
    comment << "#"

    # Columns
    comment << "# Columns:"
    columns.each do |column|
      index_info = indexes.select { |idx| idx.columns.include?(column.name) }
      index_names = index_info.map(&:name).join(", ")

      nullable = column.null ? "null" : "not null"
      default = column.default ? "default: #{column.default}" : "no default"
      index = index_names.presence ? "index: #{index_names}" : "no index"

      comment << "#  #{column.name.to_s.ljust(20)} :#{column.type.to_s.ljust(15)} #{nullable.ljust(10)} #{default.ljust(20)} #{index}"
    end

    comment << "#"

    # Indexes
    if indexes.any?
      comment << "# Indexes:"
      indexes.each do |index|
        unique = index.unique ? "unique" : "non-unique"
        comment << "#  #{index.name.to_s.ljust(30)} (#{index.columns.join(', ')}) #{unique}"
      end
      comment << "#"
    end

    comment.join("\n")
  end

  def remove_existing_schema_comment(content)
    # More aggressive removal of all schema-related comments
    lines = content.split("\n")
    filtered_lines = []
    skip_schema_lines = false

    lines.each do |line|
      stripped = line.strip

      # Start skipping when we hit any schema-related comment
      if stripped.start_with?("# == Schema Information") ||
         stripped.start_with?("# Table name:") ||
         stripped.start_with?("# Columns:") ||
         stripped.start_with?("# Indexes:")
        skip_schema_lines = true
        next
      end

      # Continue skipping schema comment lines
      if skip_schema_lines && (stripped.start_with?("#") || stripped.empty?)
        next
      end

      # Stop skipping when we hit a non-comment, non-empty line
      if skip_schema_lines && !stripped.start_with?("#") && !stripped.empty?
        skip_schema_lines = false
        filtered_lines << line
      elsif !skip_schema_lines
        filtered_lines << line
      end
    end

    filtered_lines.join("\n")
  end

  def add_schema_comment_at_bottom(content, schema_comment)
    # Clean up the content and add schema comment at the bottom
    cleaned_content = content.rstrip

    # Add schema comment at the bottom with proper spacing
    if cleaned_content.end_with?("end")
      # If the file ends with "end", add the schema comment after it
      cleaned_content + "\n\n" + schema_comment + "\n"
    else
      # Otherwise, just append to the end
      cleaned_content + "\n\n" + schema_comment + "\n"
    end
  end
end
