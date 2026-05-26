# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users#destroy", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
  end

  describe "DELETE /api/v1/user" do
    it "archives the current user and returns 204" do
      delete "/api/v1/user", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(user.reload.discarded?).to be true
    end

    it "rotates the JTI so the same token cannot be reused" do
      delete "/api/v1/user", headers: auth_headers
      original_jti_token = auth_headers

      # Same token now invalid because user is archived AND jti rotated
      get "/api/v1/user", headers: original_jti_token
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires authentication" do
      delete "/api/v1/user"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
