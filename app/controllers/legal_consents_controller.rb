# frozen_string_literal: true

class LegalConsentsController < ApplicationController
  skip_before_action :check_legal_consent!

  def new; end

  def create
    result = Legal::AcceptConsent.call(
      user: current_user,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    if result.success?
      redirect_to root_path, notice: t("legal.consent_accepted")
    else
      flash.now[:alert] = result.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end
end
