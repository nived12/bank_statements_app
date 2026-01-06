# frozen_string_literal: true

class ApiDocsController < ApplicationController
  before_action :authenticate!
  before_action :authorize_api_docs_access

  def index
    # Renders the embedded Swagger UI
  end

  private

  def authorize_api_docs_access
    # Read allowed emails from environment variable (comma-separated)
    # Example: API_DOCS_ALLOWED_EMAILS="user1@example.com,user2@example.com"
    # TODO: Replace with proper permissions system when User roles are implemented
    allowed_emails_raw = ENV.fetch("API_DOCS_ALLOWED_EMAILS", "")

    # Security: Deny access if no whitelist is configured
    if allowed_emails_raw.blank?
      flash[:alert] = t("errors.unauthorized_api_docs")
      redirect_to root_path
      return
    end

    allowed_emails = allowed_emails_raw.split(",").map(&:strip).compact_blank

    return if allowed_emails.include?(current_user.email)

    flash[:alert] = t("errors.unauthorized_api_docs")
    redirect_to root_path
  end
end
