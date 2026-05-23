# frozen_string_literal: true

module Assistant
  module Tools
    class GetStatementFiles < Base
      NAME = "get_statement_files"
      DESCRIPTION = "Returns the user's uploaded bank statement files with their status and date ranges."
      SCHEMA = {
        type: "object",
        properties: {
          limit:  { type: "integer", description: "Max files to return (default 10)" },
          status: { type: "string", description: "Filter by processing status" }
        },
        required: []
      }.freeze

      def call
        limit = [(@args[:limit] || 10).to_i, 50].min

        scope = @user.statement_files
        scope = scope.where(status: @args[:status]) if @args[:status].present?

        files = scope.order(created_at: :desc).limit(limit).map do |sf|
          {
            id: sf.id,
            filename: sf.original_filename,
            status: sf.status,
            bank: sf.respond_to?(:detected_bank) ? sf.detected_bank : nil,
            cutoff_date: sf.respond_to?(:cutoff_date) ? sf.cutoff_date&.iso8601 : nil,
            created_at: sf.created_at.iso8601
          }
        end

        success({ statement_files: files, count: files.size })
      end
    end
  end
end
