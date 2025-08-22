# Auto-run migrations on startup for Railway deployment
if Rails.env.production?
  Rails.application.config.after_initialize do
    begin
      puts "=== Starting auto-migration process ==="

      # Check if we can connect to the database
      puts "Testing database connection..."
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ Database connection successful"

      # Check if migrations are needed and run them
      puts "Checking if migrations are needed..."

      # Use the correct Rails 8 method to check and run migrations
      if defined?(ActiveRecord::Migrator)
        if ActiveRecord::Migrator.needs_migration?
          puts "🔄 Running migrations..."
          ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths)
          puts "✅ Migrations completed successfully"
        else
          puts "✅ Database is up to date"
        end
      else
        # Fallback for newer Rails versions
        puts "🔄 Running migrations (fallback method)..."
        system("bundle exec rails db:migrate")
        puts "✅ Migrations completed successfully"
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
