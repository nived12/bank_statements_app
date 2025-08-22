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

      # Get the current schema version from the database
      current_version = ActiveRecord::Base.connection.schema_version
      puts "Current schema version: #{current_version}"

      # Get all migration files and their versions
      migration_files = Dir.glob("db/migrate/*.rb").sort
      migration_versions = migration_files.map { |f| File.basename(f).split("_").first.to_i }

      # Find pending migrations (those with version > current_version)
      pending_migrations = migration_versions.select { |v| v > current_version }

      if pending_migrations.any?
        puts "🔄 Found #{pending_migrations.length} pending migrations..."
        puts "Running migrations..."

        # Use system command to run migrations (most reliable)
        result = system("bundle exec rails db:migrate")

        if result
          puts "✅ Migrations completed successfully"
        else
          puts "❌ Migration command failed"
        end
      else
        puts "✅ Database is up to date (no pending migrations)"
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
