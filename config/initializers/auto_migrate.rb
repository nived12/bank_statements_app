# Auto-run migrations on startup for Railway deployment
if Rails.env.production?
  Rails.application.config.after_initialize do
    begin
      puts "=== Starting auto-migration process ==="

      # Check if we can connect to the database
      puts "Testing database connection..."
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ Database connection successful"

      # Check if migrations are needed
      puts "Checking if migrations are needed..."
      if ActiveRecord::Base.connection.migration_context.needs_migration?
        puts "🔄 Running migrations..."
        ActiveRecord::Base.connection.migration_context.migrate
        puts "✅ Migrations completed successfully"
      else
        puts "✅ Database is up to date"
      end

    rescue ActiveRecord::ConnectionNotEstablished => e
      puts "❌ Database connection failed: #{e.message}"
    rescue => e
      puts "❌ Migration error: #{e.message}"
      puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
    end

    puts "=== Auto-migration process completed ==="
  end
end
