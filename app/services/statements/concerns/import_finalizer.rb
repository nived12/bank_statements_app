# app/services/statements/concerns/import_finalizer.rb
module Statements
  module Concerns
    module ImportFinalizer
      extend ActiveSupport::Concern

      private

      def import_and_finalize(data)
        normalized = normalize_data_keys(data)

        transaction_count = normalized["transactions"]&.size || 0
        Rails.logger.info("Importing #{transaction_count} transactions")

        # Import transactions
        import_result = Transactions::Importer.new(@statement_file, json: normalized).call
        return handle_failure("Transaction import failed") unless import_result.success?

        # Update status based on duplicates
        status_result = Statements::StatusManager.call(@statement_file, import_result.payload)
        return handle_failure("Status update failed") unless status_result.success?

        # Create financial summaries
        create_financial_summaries(normalized)

        # Reconcile potential transfers within the statement's date window (± 3 days buffer)
        reconcile_transfers_for_statement

        # Store final processed data
        @statement_file.update!(
          parsed_json: normalized,
          processed_at: Time.current
        )

        Rails.logger.info("Successfully processed statement #{@statement_file.id}")
        notify_user_statement_ready
        success(@statement_file)
      end

      def normalize_data_keys(data)
        if data.is_a?(Hash) && data.key?(:transactions)
          {
            "transactions" => data[:transactions],
            "financial_summaries" => data[:financial_summaries],
            "opening_balance" => data[:opening_balance],
            "closing_balance" => data[:closing_balance],
            "extraction_source" => data[:extraction_source]
          }
        else
          data
        end
      end

      def create_financial_summaries(data)
        summaries = data["financial_summaries"] || data[:financial_summaries]
        return unless summaries&.any?

        summaries.each do |summary_data|
          Statements::FinancialSummaryCreator.call(@statement_file, summary_data)
        end
      end

      def no_transactions?(result)
        return true unless result.is_a?(ApplicationService::Response) && result.success?

        # Check for explicit no_transactions flag
        return true if result.payload.is_a?(Hash) && result.payload[:no_transactions]

        # If payload is a StatementFile, we have transactions (they were imported)
        return false if result.payload.is_a?(StatementFile)

        transactions = result.payload&.dig(:transactions) || result.payload&.dig("transactions")
        transactions.blank?
      end

      def success_with_no_transactions
        success({ no_transactions: true })
      end

      def handle_failure(message)
        log_error(
          StandardError.new(message),
          context: "Statement processing",
          data: context_for_logging
        )

        @statement_file.update(
          status: :error,
          error_message: message,
          processed_at: Time.current
        )

        errors.add(:base, message)
        failure
      end

      def reconcile_transfers_for_statement
        txn_dates = @statement_file.transactions.pluck(:date)
        return if txn_dates.empty?

        result = Transactions::TransferReconciler.call(
          @statement_file.user,
          date_from: txn_dates.min - 3.days,
          date_to: txn_dates.max + 3.days
        )

        unless result.success?
          Rails.logger.error(
            "TransferReconciler failed for statement #{@statement_file.id}: " \
            "#{result.errors.full_messages.join(", ")}"
          )
        end
      end

      def notify_user_statement_ready
        user = @statement_file.user
        bank = @statement_file.bank_account&.bank_name || "tu banco"
        count = @statement_file.transactions.count

        Notifications::PushJob.perform_later(
          user_id: user.id,
          title: I18n.t("notifications.statement_ready.title"),
          body: I18n.t("notifications.statement_ready.body", bank: bank, count: count),
          data: { screen: "/(app)/transactions/", params: {} }
        )
      rescue StandardError => e
        Rails.logger.error("Push notification failed for statement #{@statement_file.id}: #{e.message}")
      end

      def context_for_logging
        {
          statement_file_id: @statement_file.id,
          bank_account: @statement_file.bank_account&.bank_name,
          user_id: @statement_file.user_id,
          ai_enabled: @statement_file.ai_enabled?
        }
      end
    end
  end
end
