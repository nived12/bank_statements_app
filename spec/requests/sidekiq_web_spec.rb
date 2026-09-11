require "rails_helper"

# Only the rejection path is exercised here: Rack::Auth::Basic answers before
# the dashboard runs, so this needs no Redis. The accept path is covered in
# spec/lib/sidekiq_web_auth_spec.rb.
RSpec.describe "Sidekiq Web", type: :request do
  it "refuses an unauthenticated request" do
    get "/sidekiq"

    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses wrong credentials" do
    get "/sidekiq", headers: {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("nope", "nope")
    }

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not leak the dashboard in the rejection body" do
    get "/sidekiq"

    expect(response.body).not_to include("Sidekiq")
  end
end
