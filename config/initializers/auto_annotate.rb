# frozen_string_literal: true

# Auto-annotate models after migrations
# This ensures model files always have up-to-date schema information

if Rails.env.development?
  # Hook into Rails migration events
  ActiveSupport.on_load(:active_record) do
    # Run schema annotation after db:migrate
    Rake::Task["db:migrate"].enhance do
      Rake::Task["schema:annotate"].invoke
    end

    # Run schema annotation after db:rollback
    Rake::Task["db:rollback"].enhance do
      Rake::Task["schema:annotate"].invoke
    end if Rake::Task.task_defined?("db:rollback")
  end
end
