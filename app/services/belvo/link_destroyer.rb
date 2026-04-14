class Belvo::LinkDestroyer < ApplicationService
  def initialize(belvo_link:)
    super()
    @belvo_link = belvo_link
  end

  def call
    delete_from_belvo_api
    @belvo_link.update!(status: :inactive, sync_status: :error, sync_error_message: "Disconnected by user")
    @belvo_link.bank_accounts.update_all(belvo_link_id: nil, belvo_account_id: nil, sync_status: nil)
    success(@belvo_link)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.message)
  end

  private

  def delete_from_belvo_api
    client_result = Belvo::ClientFactory.call
    return unless client_result.success?

    client_result.payload.links.delete(id: @belvo_link.belvo_link_id)
  rescue ::Belvo::RequestError => e
    Rails.logger.warn("Failed to delete Belvo link #{@belvo_link.belvo_link_id}: #{e.message}")
  end
end
