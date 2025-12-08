# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::RefreshTokensService do
  let(:user) { create(:user) }
  let!(:generate_result) { Auth::GenerateTokensService.call(user) }
  let(:refresh_token) { generate_result.payload[:refresh_token] }

  describe "#call" do
    context "with valid refresh token" do
      it "generates new access and refresh tokens" do
        result = described_class.call(refresh_token)

        expect(result).to be_success
        expect(result.payload).to have_key(:access_token)
        expect(result.payload).to have_key(:refresh_token)
        expect(result.payload).to have_key(:expires_in)
        expect(result.payload).to have_key(:token_type)
      end

      it "returns different tokens than the original" do
        original_access_token = generate_result.payload[:access_token]
        original_refresh_token = refresh_token

        result = described_class.call(refresh_token)

        expect(result).to be_success
        expect(result.payload[:access_token]).not_to eq(original_access_token)
        expect(result.payload[:refresh_token]).not_to eq(original_refresh_token)
      end

      it "updates user jti" do
        old_jti = user.reload.jti

        result = described_class.call(refresh_token)

        expect(result).to be_success
        expect(user.reload.jti).not_to eq(old_jti)
      end

      it "generates valid new tokens" do
        result = described_class.call(refresh_token)

        expect(result).to be_success

        # Decode new access token
        access_token_payload = JsonWebToken.decode(result.payload[:access_token])
        expect(access_token_payload).to be_present
        expect(access_token_payload[:user_id]).to eq(user.id)
        expect(access_token_payload[:type]).to eq("access")

        # Decode new refresh token
        refresh_token_payload = JsonWebToken.decode(result.payload[:refresh_token])
        expect(refresh_token_payload).to be_present
        expect(refresh_token_payload[:user_id]).to eq(user.id)
        expect(refresh_token_payload[:type]).to eq("refresh")
      end
    end

    context "with invalid input" do
      it "fails when refresh token is nil" do
        result = described_class.call(nil)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Refresh token is required")
      end

      it "fails when refresh token is blank" do
        result = described_class.call("")

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Refresh token is required")
      end

      it "fails when refresh token is invalid" do
        result = described_class.call("invalid_token")

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Invalid or expired refresh token")
      end

      it "fails when token is expired" do
        # Generate expired token
        expired_payload = {
          user_id: user.id,
          jti: user.jti,
          type: "refresh",
          exp: 1.day.ago.to_i,
          iat: 2.days.ago.to_i,
          nbf: 2.days.ago.to_i,
          iss: JwtConfig.issuer,
          aud: JwtConfig.audience
        }
        expired_token = JWT.encode(expired_payload, JwtConfig.secret_key, "HS256")

        result = described_class.call(expired_token)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Invalid or expired refresh token")
      end
    end

    context "with wrong token type" do
      it "fails when using access token instead of refresh token" do
        access_token = generate_result.payload[:access_token]

        result = described_class.call(access_token)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Invalid token type")
      end
    end

    context "when token has been revoked" do
      it "fails when user jti doesn't match token jti" do
        # Change user's JTI (simulating token revocation)
        user.update!(jti: SecureRandom.uuid)

        result = described_class.call(refresh_token)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Token has been revoked")
      end
    end

    context "when user doesn't exist" do
      it "fails when user is not found" do
        # Create token with non-existent user ID
        fake_payload = {
          user_id: 999999,
          jti: SecureRandom.uuid,
          type: "refresh"
        }
        fake_token = JsonWebToken.encode(fake_payload, JsonWebToken::REFRESH_TOKEN_EXPIRATION)

        result = described_class.call(fake_token)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("User not found")
      end
    end

    context "when refresh token has expired in database" do
      it "fails when refresh_token_expires_at is in the past" do
        user.update!(refresh_token_expires_at: 1.day.ago)

        result = described_class.call(refresh_token)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Refresh token expired or invalid")
      end

      it "fails when refresh_token_expires_at is nil in database" do
        user.update!(refresh_token_expires_at: nil)

        result = described_class.call(refresh_token)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Refresh token expired or invalid")
      end
    end
  end
end
