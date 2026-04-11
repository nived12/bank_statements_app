class BelvoLinksController < ApplicationController
  before_action :check_subscription
  before_action :set_belvo_link, only: [:destroy, :sync, :reauth]

  # GET /belvo_links/new
  def new
    unless current_user.can_connect_bank?
      redirect_to bank_accounts_path, alert: t("belvo.limit_reached")
      return
    end

    result = Belvo::AccessTokenGenerator.call(user: current_user)
    if result.success?
      @access_token = result.payload
      @belvo_environment = Rails.application.config.belvo.environment
    else
      redirect_to bank_accounts_path, alert: t("belvo.connection_error")
    end
  end

  # POST /belvo_links
  def create
    result = Belvo::LinkCreator.call(
      user: current_user,
      link_id: params[:link_id],
      institution: params[:institution]
    )

    if result.success?
      redirect_to bank_accounts_path, notice: t("belvo.connected_successfully")
    else
      redirect_to bank_accounts_path, alert: t("belvo.connection_failed")
    end
  end

  # DELETE /belvo_links/:id
  def destroy
    Belvo::LinkDestroyer.call(belvo_link: @belvo_link)
    redirect_to bank_accounts_path, notice: t("belvo.disconnected_successfully")
  end

  # POST /belvo_links/:id/sync
  def sync
    BelvoSyncJob.perform_later(@belvo_link.id)
    redirect_to bank_accounts_path, notice: t("belvo.sync_started")
  end

  # GET /belvo_links/:id/reauth
  def reauth
    result = Belvo::AccessTokenGenerator.call(user: current_user, link_id: @belvo_link.belvo_link_id)
    if result.success?
      @access_token = result.payload
      @belvo_environment = Rails.application.config.belvo.environment
      @belvo_link_id = @belvo_link.id
    else
      redirect_to bank_accounts_path, alert: t("belvo.connection_error")
    end
  end

  private

  def set_belvo_link
    @belvo_link = current_user.belvo_links.find(params[:id])
  end

  def check_subscription
    access = current_user.subscription_access_result(i18n_scope: "belvo.access_denied")
    return if access[:allowed]

    redirect_to bank_accounts_path, alert: t("belvo.subscription_required")
  end
end
