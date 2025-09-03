# frozen_string_literal: true

##
# FileHandling
# Concern module for file handling operations that can be included in services
#
# Usage:
# include FileHandling in your service class and you can use:
#   temp_file = create_temp_file(statement)
#   cleanup_temp_file(temp_file)
#
module FileHandling
  private

  def create_temp_file(statement)
    temp_file = Tempfile.new([ "statement", ".pdf" ], binmode: true)
    temp_file.write(statement.file.download)
    temp_file.rewind
    temp_file
  end

  def cleanup_temp_file(temp_file)
    temp_file&.close!
  rescue => e
    Rails.logger.error("Failed to cleanup temp file: #{e.message}")
  end
end
