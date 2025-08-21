# Auto-run migrations on startup for Railway deployment
if Rails.env.production?
  Rails.application.config.after_initialize do
    begin
      puts "Checking database connection..."
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "Database connection established, running migrations..."

      # Run migrations
      Rake::Task["db:migrate"].invoke
      puts "Migrations completed successfully"
    rescue ActiveRecord::ConnectionNotEstablished => e
      puts "Database not ready: #{e.message}"
    rescue => e
      puts "Migration error: #{e.message}"
    end
  end
end
