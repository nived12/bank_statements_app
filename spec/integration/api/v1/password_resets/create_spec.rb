# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Password Resets - Create", type: :request) do
  path "/api/v1/password_resets" do
    post "Request password reset" do
      tags "Password Reset"
      consumes "application/json"
      produces "application/json"
      description "Request a password reset email. Returns success message regardless of whether email exists (security measure to prevent email enumeration)."

      parameter name: :email_params, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, description: "Email address to send password reset instructions", example: "user@example.com" }
        },
        required: [:email],
        example: {
          email: "user@example.com"
        }
      }

      response "200", "Password reset email sent (if email exists)" do
        let!(:user) { create(:user, :confirmed, email: "user@example.com") }
        let(:email_params) { { email: "user@example.com" } }

        run_test! do |response|
          expect(response.body).to be_empty
        end
      end
    end
  end
end
