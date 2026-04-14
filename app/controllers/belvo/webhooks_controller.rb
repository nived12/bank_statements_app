class Belvo::WebhooksController < ActionController::API
  before_action :verify_webhook_signature

  def create
    case params[:event_type]
    when "transactions_available"
      handle_transactions_available
    when "link_status_changed"
      handle_link_status_changed
    end

    head :ok
  end

  private

  def verify_webhook_signature
    webhook_secret = ENV.fetch("BELVO_WEBHOOK_SECRET", nil)
    return if webhook_secret.blank? # Skip verification if not configured

    signature = request.headers["X-Belvo-Signature"]
    return head(:unauthorized) if signature.blank?

    body = request.raw_post
    expected = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)
    head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end

  def handle_transactions_available
    link = BelvoLink.find_by(belvo_link_id: params[:link_id])
    return unless link

    BelvoSyncJob.perform_later(link.id)
  end

  def handle_link_status_changed
    link = BelvoLink.find_by(belvo_link_id: params[:link_id])
    return unless link

    new_status = map_belvo_status(params[:status])
    link.update!(status: new_status) if new_status
  end

  def map_belvo_status(belvo_status)
    case belvo_status.to_s.downcase
    when "valid", "active" then "active"
    when "invalid", "unconfirmed" then "login_error"
    when "token_required" then "token_required"
    else "inactive"
    end
  end
end
