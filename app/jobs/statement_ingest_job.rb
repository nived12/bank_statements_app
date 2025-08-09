class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find_by(id: statement_file_id)
    return unless statement

    statement.update(status: "processing")

    temp_file = Tempfile.new([ "statement_#{statement.id}", File.extname(statement.file.filename.to_s) ])
    begin
      temp_file.binmode
      temp_file.write(statement.file.download)
      temp_file.rewind

      # TODO: Implement parsing later
      statement.update(
        status: "parsed",
        processed_at: Time.current,
        parsed_json: { message: "placeholder - parsing not implemented yet" }
      )
    rescue => e
      statement.update(status: "error")
      Rails.logger.error("StatementIngestJob failed: #{e.message}")
    ensure
      temp_file.close!
    end
  end
end
