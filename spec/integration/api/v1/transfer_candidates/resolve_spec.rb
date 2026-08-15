# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transfer Candidates - Resolve", type: :request) do
  path("/api/v1/transfer_candidates/resolve") do
    post("Accept or dismiss transfer candidates") do
      tags("Transfer Candidates")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description(
        "Accepts and dismisses candidates in a single call, so a client can batch a review " \
        "pass and submit it once. Accepted pairs are linked as transfers and drop out of " \
        "income and expense totals. **Dismissing is permanent** — the reconciler never " \
        "re-offers a rejected pair, including when a later backfill gives both sides the " \
        "same clave de rastreo. Ids belonging to another user are ignored, not rejected."
      )

      parameter(
        name: :body, in: :body, required: false,
        schema: {
          type: :object,
          properties: {
            accepted_ids: {
              type: :array, items: { type: :integer },
              description: "Candidates to link as transfers"
            },
            rejected_ids: {
              type: :array, items: { type: :integer },
              description: "Candidates to dismiss permanently"
            }
          }
        }
      )

      response("200", "Candidates resolved") do
        schema(
          type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                linked_count: { type: :integer },
                rejected_count: { type: :integer }
              },
              required: %w[linked_count rejected_count]
            }
          },
          required: %w[data]
        )

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:outgoing) do
          create(:transaction, user: user, bank_account: create(:bank_account, user: user), amount: -14_000.00)
        end
        let(:incoming) do
          create(:transaction, :income, user: user, bank_account: create(:bank_account, user: user), amount: 14_000.00)
        end
        let(:candidate) do
          create(:transfer_candidate, user: user, outgoing_transaction: outgoing, incoming_transaction: incoming)
        end
        let(:body) { { accepted_ids: [candidate.id] } }

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:body) { {} }

        run_test!
      end
    end
  end
end
