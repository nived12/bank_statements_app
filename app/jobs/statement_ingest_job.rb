# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    StatementProcessingOrchestrator.call(statement_file_id)
  end
end
