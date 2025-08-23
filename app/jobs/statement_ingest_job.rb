# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find(statement_file_id)
    statement.update(status: "processing")

    Rails.logger.info("Starting statement processing for file #{statement_file_id} with AI #{statement.ai_enabled? ? 'enabled' : 'disabled'}")

    orchestrator = StatementProcessingOrchestrator.new(statement)
    orchestrator.process
  end
end
