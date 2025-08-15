namespace :schema do
  desc "Look up schema information for a specific table (usage: rake schema:lookup[table_name])"
  task :lookup, [ :table_name ] => :environment do |task, args|
    table_name = args[:table_name]

    if table_name.blank?
      puts "Usage: rake schema:lookup[table_name]"
      puts "Available tables:"
      ActiveRecord::Base.connection.tables.sort.each do |table|
        puts "  - #{table}"
      end
      exit 1
    end

    unless ActiveRecord::Base.connection.table_exists?(table_name)
      puts "Table '#{table_name}' does not exist."
      puts "Available tables:"
      ActiveRecord::Base.connection.tables.sort.each do |table|
        puts "  - #{table}"
      end
      exit 1
    end

    columns = ActiveRecord::Base.connection.columns(table_name)
    indexes = ActiveRecord::Base.connection.indexes(table_name)

    puts "=== Schema for table: #{table_name} ==="
    puts

    puts "Columns:"
    puts "  #{'Name'.ljust(25)} #{'Type'.ljust(15)} #{'Nullable'.ljust(10)} #{'Default'.ljust(15)} #{'Index'.ljust(30)}"
    puts "  #{'-' * 25} #{'-' * 15} #{'-' * 10} #{'-' * 15} #{'-' * 30}"

    columns.each do |column|
      index_info = indexes.select { |idx| idx.columns.include?(column.name) }
      index_names = index_info.map(&:name).join(", ")

      nullable = column.null ? "YES" : "NO"
      default = column.default || "NULL"
      index = index_names.presence || "-"

      puts "  #{column.name.ljust(25)} #{column.type.to_s.ljust(15)} #{nullable.ljust(10)} #{default.to_s.ljust(15)} #{index.ljust(30)}"
    end

    puts

    if indexes.any?
      puts "Indexes:"
      puts "  #{'Name'.ljust(40)} #{'Columns'.ljust(30)} #{'Unique'.ljust(10)}"
      puts "  #{'-' * 40} #{'-' * 30} #{'-' * 10}"

      indexes.each do |index|
        unique = index.unique ? "YES" : "NO"
        puts "  #{index.name.ljust(40)} #{index.columns.join(', ').ljust(30)} #{unique.ljust(10)}"
      end
    else
      puts "No indexes defined."
    end

    puts
    puts "Total: #{columns.count} columns, #{indexes.count} indexes"
  end

  desc "List all tables with basic info"
  task tables: :environment do
    puts "=== Available Tables ==="
    puts

    ActiveRecord::Base.connection.tables.sort.each do |table|
      columns_count = ActiveRecord::Base.connection.columns(table).count
      indexes_count = ActiveRecord::Base.connection.indexes(table).count

      puts "#{table.ljust(30)} #{columns_count.to_s.rjust(3)} columns, #{indexes_count.to_s.rjust(2)} indexes"
    end

    puts
    puts "Total: #{ActiveRecord::Base.connection.tables.count} tables"
  end
end
