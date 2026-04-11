class Belvo::AccessTokenGenerator < ApplicationService
  def initialize(user:, link_id: nil)
    super()
    @user = user
    @link_id = link_id
  end

  def call
    client_result = Belvo::ClientFactory.call
    return failure("Could not initialize Belvo client") unless client_result.success?

    client = client_result.payload

    options = { link: @link_id }
    token_response = client.widget_token.create(options: options)

    if token_response.is_a?(Hash) && token_response["access"].present?
      success(token_response["access"])
    else
      failure("Failed to generate Belvo widget token")
    end
  rescue ::Belvo::RequestError => e
    failure("Belvo token generation failed: #{e.message}")
  end
end
