# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Banks - Index", type: :request do
  describe "GET /api/v1/banks" do
    let!(:debit_bank) { create(:bank, :debit_only, name: "ZZZ Debit Bank", active: true) }
    let!(:credit_bank) { create(:bank, :credit_only, name: "ZZZ Credit Bank", active: true) }
    let!(:both_bank) { create(:bank, name: "ZZZ Both Bank", supported_type: "both", active: true) }
    let!(:inactive_bank) { create(:bank, :inactive, name: "ZZZ Inactive Bank") }

    context "without filters" do
      it "returns only active banks" do
        get "/api/v1/banks"

        json = JSON.parse(response.body)
        names = json["data"]["banks"].map { |b| b["name"] }
        expect(names).not_to include("ZZZ Inactive Bank")
      end

      it "includes the banks we created" do
        get "/api/v1/banks"

        json = JSON.parse(response.body)
        names = json["data"]["banks"].map { |b| b["name"] }
        expect(names).to include("ZZZ Debit Bank", "ZZZ Credit Bank", "ZZZ Both Bank")
      end

      it "returns banks in alphabetical order (case-insensitive)" do
        get "/api/v1/banks"

        json = JSON.parse(response.body)
        names = json["data"]["banks"].map { |b| b["name"] }
        expect(names).to eq(names.sort_by(&:downcase))
      end

      it "returns required fields for each bank" do
        get "/api/v1/banks"

        json = JSON.parse(response.body)
        bank = json["data"]["banks"].first
        expect(bank).to include("id", "code", "name", "logo_url", "supported_type")
      end

      it "does not require authentication" do
        get "/api/v1/banks"
        expect(response).not_to have_http_status(:unauthorized)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with account_type filter" do
      it "includes debit-compatible banks when account_type=debit" do
        get "/api/v1/banks", params: { account_type: "debit" }

        json = JSON.parse(response.body)
        names = json["data"]["banks"].map { |b| b["name"] }
        expect(names).to include("ZZZ Debit Bank", "ZZZ Both Bank")
        expect(names).not_to include("ZZZ Credit Bank")
      end

      it "includes credit-compatible banks when account_type=credit" do
        get "/api/v1/banks", params: { account_type: "credit" }

        json = JSON.parse(response.body)
        names = json["data"]["banks"].map { |b| b["name"] }
        expect(names).to include("ZZZ Credit Bank", "ZZZ Both Bank")
        expect(names).not_to include("ZZZ Debit Bank")
      end

      it "excludes inactive banks even when account_type filter matches" do
        get "/api/v1/banks", params: { account_type: "debit" }

        json = JSON.parse(response.body)
        names = json["data"]["banks"].map { |b| b["name"] }
        expect(names).not_to include("ZZZ Inactive Bank")
      end
    end
  end
end
