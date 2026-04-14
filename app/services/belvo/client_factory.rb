class Belvo::ClientFactory < ApplicationService
  def call
    config = Rails.application.config.belvo

    unless config.secret_id.present? && config.secret_password.present?
      return failure("Belvo API credentials are not configured")
    end

    client = ::Belvo::Client.new(
      config.secret_id,
      config.secret_password,
      config.environment
    )
    success(client)
  rescue ::Belvo::BelvoAPIError => e
    failure("Belvo client initialization failed: #{e.message}")
  end
end
