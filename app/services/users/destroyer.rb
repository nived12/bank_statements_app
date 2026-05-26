# frozen_string_literal: true

module Users
  # Hard-deletes a user — used only via the `rake users:hard_delete` task
  # when a user explicitly invokes LFPDPPP Art. 22 right-to-erasure.
  #
  # NOT wired to any controller. The UI uses Users::Archiver.
  #
  # Requires the user to be archived first — prevents accidental hard-delete
  # without the soft-delete safety net.
  class Destroyer < ApplicationService
    def initialize(user:)
      super()
      @user = user
    end

    def call
      unless @user.discarded?
        return failure("user must be archived before hard delete")
      end

      ActiveRecord::Base.transaction do
        purge_data
        anonymize_user
      end

      success
    rescue => e
      Rails.logger.error("Users::Destroyer failed for user #{@user.id}: #{e.class}: #{e.message}")
      failure(e.message)
    end

    private

    def purge_data
      @user.statement_files.find_each do |sf|
        sf.file.purge_later if sf.file.attached?
      end
      @user.statement_files.destroy_all
      @user.transactions.destroy_all
      @user.bank_accounts.destroy_all
      @user.assistant_conversations.destroy_all
    end

    def anonymize_user
      # Retain legal_consents rows per LFPDPPP Art. 14 (5-year retention)
      # Nullify the user FK so rows remain but are no longer linked.
      @user.legal_consents.update_all(user_id: nil)

      @user.update_columns(
        email: "deleted-#{@user.id}@vitt.io",
        first_name: "deleted",
        last_name: "user",
        password_digest: SecureRandom.hex(32),
        confirmed_at: nil,
        jti: SecureRandom.uuid
      )
    end
  end
end
