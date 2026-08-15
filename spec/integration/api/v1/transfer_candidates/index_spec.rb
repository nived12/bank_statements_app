# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transfer Candidates - Index", type: :request) do
  path("/api/v1/transfer_candidates") do
    get("List transfer candidates awaiting review") do
      tags("Transfer Candidates")
      produces("application/json")
      security([Bearer: []])
      description(
        "Transfer pairs the reconciler found but would not link on its own — different " \
        "dates, tied scores, or descriptions that never say \"transfer\". Returns only " \
        "pending candidates whose transactions are both still unlinked."
      )

      response("200", "Candidates retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_transfer_candidates_list_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:outgoing) do
          create(:transaction, user: user, bank_account: create(:bank_account, user: user), amount: -14_000.00)
        end
        let(:incoming) do
          create(:transaction, :income, user: user, bank_account: create(:bank_account, user: user), amount: 14_000.00)
        end
        let!(:candidate) do
          create(:transfer_candidate, user: user, outgoing_transaction: outgoing, incoming_transaction: incoming)
        end

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
