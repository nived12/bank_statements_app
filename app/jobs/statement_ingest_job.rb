# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find(statement_file_id)
    statement.update(status: "processing")

    orchestrator = StatementProcessingOrchestrator.new(statement)
    orchestrator.process
  end
end
