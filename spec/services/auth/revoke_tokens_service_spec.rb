# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::RevokeTokensService do
  let(:user) { create(:user) }

  describe "#call" do
    context "with valid user" do
      before do
        # Generate tokens for the user first
        Auth::GenerateTokensService.call(user)
        user.reload
      end

      it "revokes all tokens successfully" do
        result = described_class.call(user)

        expect(result).to be_success
        expect(result.payload[:message]).to eq("Tokens revoked successfully")
      end

      it "changes user jti" do
        old_jti = user.jti

        result = described_class.call(user)

        expect(result).to be_success
        user.reload
        expect(user.jti).not_to eq(old_jti)
        expect(user.jti).to be_present
      end

      it "clears refresh token expiration" do
        expect(user.refresh_token_expires_at).to be_present

        result = described_class.call(user)

        expect(result).to be_success
        user.reload
        expect(user.refresh_token_expires_at).to be_nil
      end

      it "invalidates existing access tokens" do
        # Generate tokens
        generate_result = Auth::GenerateTokensService.call(user)
        old_access_token = generate_result.payload[:access_token]

        # Verify old token is valid before revocation
        decoded = JsonWebToken.decode(old_access_token)
        expect(decoded).to be_present
        expect(decoded[:jti]).to eq(user.reload.jti)

        # Revoke tokens
        result = described_class.call(user)
        expect(result).to be_success

        # Old token's JTI won't match user's new JTI
        user.reload
        expect(decoded[:jti]).not_to eq(user.jti)
      end

      it "invalidates existing refresh tokens" do
        # Generate tokens
        generate_result = Auth::GenerateTokensService.call(user)
        old_refresh_token = generate_result.payload[:refresh_token]

        # Revoke tokens
        result = described_class.call(user)
        expect(result).to be_success

        # Try to use old refresh token
        refresh_result = Auth::RefreshTokensService.call(old_refresh_token)
        expect(refresh_result).to be_failure
      end
    end

    context "with invalid input" do
      it "fails when user is nil" do
        result = described_class.call(nil)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("User is required")
      end
    end

    context "when user update fails" do
      it "returns failure with errors" do
        allow(user).to receive(:update).and_return(false)
        allow(user).to receive(:errors).and_return(
          ActiveModel::Errors.new(user).tap { |e| e.add(:jti, "is invalid") }
        )

        result = described_class.call(user)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("Failed to revoke tokens")
      end
    end

    context "with user who never had tokens" do
      it "still succeeds and sets new jti" do
        user_without_tokens = create(:user)
        expect(user_without_tokens.jti).to be_nil

        result = described_class.call(user_without_tokens)

        expect(result).to be_success
        user_without_tokens.reload
        expect(user_without_tokens.jti).to be_present
      end
    end
  end
end
