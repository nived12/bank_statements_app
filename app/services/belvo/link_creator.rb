class Belvo::LinkCreator < ApplicationService
  def initialize(user:, link_id:, institution:)
    super()
    @user = user
    @link_id = link_id
    @institution = institution
  end

  def call
    unless @user.can_connect_bank?
      return failure(I18n.t("belvo.access_denied.subscription_required"))
    end

    bank = resolve_bank
    belvo_link = BelvoLink.create!(
      user: @user,
      bank: bank,
      belvo_link_id: @link_id,
      belvo_institution: @institution,
      status: :active,
      access_mode: "recurrent",
      sync_status: :pending
    )

    BelvoSyncJob.perform_later(belvo_link.id)
    success(belvo_link)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.message)
  end

  private

  def resolve_bank
    result = Belvo::InstitutionMapper.call(@institution)
    result.success? ? result.payload : nil
  end
end
