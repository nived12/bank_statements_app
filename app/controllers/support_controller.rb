# frozen_string_literal: true

# Public support page. Required by App Store Review Guideline 1.5 (the Support URL
# submitted to App Store Connect must resolve to a working page with contact info)
# and by Play Console's store listing. Public — no auth, no legal gate.
class SupportController < ApplicationController
  include MarketingLayout

  SUPPORT_EMAIL = "support@vitt.io"

  helper_method :support_email

  def index; end

  private

  def support_email
    SUPPORT_EMAIL
  end
end
