# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    Rails.logger.info("Using Vision-based processor for statement #{statement_file_id}")
    Statements::Processor.call(statement_file_id)
  end
end
