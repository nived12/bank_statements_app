# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    # Feature flag to switch between old and new processing architecture
    if use_vision_processor?
      Rails.logger.info("Using new Vision-based processor for statement #{statement_file_id}")
      Statements::Processor.call(statement_file_id)
    else
      Rails.logger.info("Using legacy orchestrator for statement #{statement_file_id}")
      StatementProcessingOrchestrator.call(statement_file_id)
    end
  end

  private

  def use_vision_processor?
    # Enable new processor via environment variable
    # Set USE_VISION_PROCESSOR=true to enable
    ENV["USE_VISION_PROCESSOR"]&.downcase == "true"
  end
end
