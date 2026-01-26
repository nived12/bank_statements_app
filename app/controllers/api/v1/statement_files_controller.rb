# frozen_string_literal: true

module Api
  module V1
    class StatementFilesController < BaseController
      before_action :set_statement_file, only: [:show, :destroy, :retry]

      # GET /api/v1/statement_files
      def index
        @statement_files = current_user.statement_files
                                       .includes(:bank_account)
                                       .order(Arel.sql("COALESCE(cutoff_date, created_at) DESC"))
        @statement_files = paginate(@statement_files)
      end

      # GET /api/v1/statement_files/:id
      def show; end

      # POST /api/v1/statement_files
      def create
        return unless validate_file_upload

        @statement_file = current_user.statement_files.new(statement_file_params)

        if @statement_file.save
          StatementIngestJob.perform_later(@statement_file.id)
          @message = "Statement file uploaded successfully"
          render(:show, status: :created)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to upload statement file",
            status: :unprocessable_entity,
            details: format_validation_errors(@statement_file.errors)
          )
        end
      end

      # DELETE /api/v1/statement_files/:id
      def destroy
        ActiveRecord::Base.transaction do
          # Delete transactions that were created from this statement file
          statement_file_transactions = @statement_file.transactions.where(source: :statement_file)
          statement_file_transactions.destroy_all if statement_file_transactions.any?

          # For manual transactions, only remove the statement_file_id reference
          manual_transactions = @statement_file.transactions.where(source: :manual)
          manual_transactions.update_all(statement_file_id: nil) if manual_transactions.any?

          # Now we can safely delete the statement file
          @statement_file.destroy!
        end

        head(:no_content)
      rescue ActiveRecord::RecordNotDestroyed
        render_error(
          "DELETE_FAILED",
          message: "Failed to delete statement file",
          status: :unprocessable_entity
        )
      rescue StandardError => e
        Rails.logger.error "Error deleting statement file: #{e.message}"
        render_error(
          "DELETE_FAILED",
          message: "An error occurred while deleting the statement file",
          status: :internal_server_error
        )
      end

      # POST /api/v1/statement_files/:id/retry
      def retry
        unless @statement_file.error?
          render_error(
            "RETRY_NOT_ALLOWED",
            message: "Only failed statement files can be retried",
            status: :unprocessable_entity
          )
          return
        end

        @statement_file.update(
          status: :pending,
          error_message: nil,
          processed_at: nil
        )

        StatementIngestJob.perform_later(@statement_file.id)

        @message = "Statement file processing restarted"
        render(:show, status: :ok)
      end

      private

      def set_statement_file
        @statement_file = current_user.statement_files.find(params[:id])
      end

      def validate_file_upload
        file = params.dig(:statement_file, :file)

        if file.blank?
          render_error("FILE_REQUIRED", message: "File is required", status: :bad_request)
          return false
        end

        if file.content_type != "application/pdf"
          render_error("INVALID_FILE_TYPE", message: "Only PDF files are supported", status: :unprocessable_entity)
          return false
        end

        if file.size > 10.megabytes
          render_error(
            "FILE_TOO_LARGE",
            message: "File size exceeds maximum allowed (10MB)",
            status: :unprocessable_entity
          )
          return false
        end

        true
      end

      def statement_file_params
        params.require(:statement_file).permit(
          :bank_account_id, :file, :processing_strategy, :cutoff_date
        ).tap do |permitted|
          # Handle cutoff_date: accept both date strings and UTC datetimes
          if permitted[:cutoff_date].present?
            cutoff_value = permitted[:cutoff_date].to_s

            # Check if input contains time information (has 'T' separator or time component)
            # Examples: "2024-01-15" vs "2024-01-15T14:30:45Z" or "2024-01-15 14:30:45"
            has_time_component = cutoff_value.match?(/[T\s]\d{2}:\d{2}/)

            if has_time_component
              # Input has time - parse and use as-is (convert to UTC if needed)
              permitted[:cutoff_date] = Time.zone.parse(cutoff_value).utc
            else
              # Input is just a date - convert to end-of-day UTC
              date = Date.parse(cutoff_value)
              permitted[:cutoff_date] = Time.zone.parse("#{date} 23:59:59").utc
            end
          end

          # Validate processing_strategy: use param if valid, else user's default
          valid_strategies = %w[parser_only text_with_ai vision_ai]
          unless valid_strategies.include?(permitted[:processing_strategy])
            permitted[:processing_strategy] = current_user.user_settings.processing_strategy
          end
        end
      end
    end
  end
end
