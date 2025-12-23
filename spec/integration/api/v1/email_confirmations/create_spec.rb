# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Email Confirmations - Create", type: :request) do
  path "/api/v1/email_confirmations" do
    post "Resend confirmation email" do
      tags "Email Confirmation"
      consumes "application/json"
      produces "application/json"
      description "Request a new confirmation email. Returns success message regardless of whether email exists or is already confirmed (security measure to prevent email enumeration)."

      parameter name: :email_params, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, description: "Email address to send confirmation instructions", example: "user@example.com" }
        },
        required: [:email],
        example: {
          email: "user@example.com"
        }
      }

      response "200", "Confirmation email sent (if email exists and not confirmed)" do
        let!(:user) { create(:user, email: "user@example.com", confirmed_at: nil) }
        let(:email_params) { { email: "user@example.com" } }

        run_test! do |response|
          expect(response.body).to be_empty
        end
      end
    end
  end
end
