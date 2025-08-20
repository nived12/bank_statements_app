# app/services/file_handling_service.rb
class FileHandlingService
  def self.create_temp_file(statement)
    temp_file = Tempfile.new([ "statement", ".pdf" ], binmode: true)
    temp_file.write(statement.file.download)
    temp_file.rewind
    temp_file
  end

  def self.cleanup_temp_file(temp_file)
    temp_file&.close!
  rescue => e
    Rails.logger.error("Failed to cleanup temp file: #{e.message}")
  end
end
