# frozen_string_literal: true

module Legal
  class AcceptConsent < ApplicationService
    def initialize(user:, ip_address: nil, user_agent: nil, version: LegalDocument::CURRENT_VERSION)
      super()
      @user = user
      @ip_address = ip_address
      @user_agent = user_agent
      @version = version
    end

    def call
      return failure("User is required") if @user.blank?

      ActiveRecord::Base.transaction do
        create_audit_records
        update_user_consent_timestamps
      end

      success({ version: @version, accepted_at: Time.current })
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message)
    end

    private

    def create_audit_records
      now = Time.current
      LegalDocument::REQUIRED_DOCUMENTS.each do |doc_type|
        LegalConsent.create!(
          user: @user,
          email: @user.email,
          document_type: doc_type,
          document_version: @version,
          accepted_at: now,
          ip_address: @ip_address,
          user_agent: @user_agent
        )
      end
    end

    def update_user_consent_timestamps
      now = Time.current
      @user.update!(
        terms_accepted_at: now,
        privacy_accepted_at: now,
        legal_version_accepted: @version
      )
    end

    def context_for_logging
      { user_id: @user&.id, version: @version }
    end
  end
end
