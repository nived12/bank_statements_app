# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::GenerateTokensService do
  let(:user) { create(:user) }

  describe "#call" do
    context "with valid user" do
      it "generates access and refresh tokens" do
        result = described_class.call(user)

        expect(result).to be_success
        expect(result.payload).to have_key(:access_token)
        expect(result.payload).to have_key(:refresh_token)
        expect(result.payload).to have_key(:expires_in)
        expect(result.payload).to have_key(:token_type)
        expect(result.payload[:token_type]).to eq("Bearer")
      end

      it "updates user with jti and refresh token expiration" do
        expect {
          described_class.call(user)
        }.to change { user.reload.jti }.from(nil)
          .and change { user.refresh_token_expires_at }.from(nil)
      end

      it "sets refresh token expiration to 7 days from now" do
        freeze_time do
          result = described_class.call(user)

          expect(result).to be_success
          user.reload
          expect(user.refresh_token_expires_at).to be_within(1.second).of(7.days.from_now)
        end
      end

      it "generates valid JWT tokens" do
        result = described_class.call(user)

        expect(result).to be_success

        # Decode access token
        access_token_payload = JsonWebToken.decode(result.payload[:access_token])
        expect(access_token_payload).to be_present
        expect(access_token_payload[:user_id]).to eq(user.id)
        expect(access_token_payload[:type]).to eq("access")
        expect(access_token_payload[:jti]).to eq(user.reload.jti)

        # Decode refresh token
        refresh_token_payload = JsonWebToken.decode(result.payload[:refresh_token])
        expect(refresh_token_payload).to be_present
        expect(refresh_token_payload[:user_id]).to eq(user.id)
        expect(refresh_token_payload[:type]).to eq("refresh")
        expect(refresh_token_payload[:jti]).to eq(user.jti)
      end

      it "generates unique jti for each call" do
        result1 = described_class.call(user)
        first_jti = user.reload.jti

        result2 = described_class.call(user)
        second_jti = user.reload.jti

        expect(result1).to be_success
        expect(result2).to be_success
        expect(first_jti).not_to eq(second_jti)
      end
    end

    context "with invalid input" do
      it "fails when user is nil" do
        result = described_class.call(nil)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("User is required")
      end

      it "fails when user is not persisted" do
        unsaved_user = build(:user)

        result = described_class.call(unsaved_user)

        expect(result).to be_failure
        expect(result.errors[:base]).to include("User must be persisted")
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
        expect(result.errors[:base]).to include("Failed to update user tokens")
      end
    end
  end
end
