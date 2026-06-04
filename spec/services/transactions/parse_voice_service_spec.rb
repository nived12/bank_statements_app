# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transactions::ParseVoiceService do
  let(:user) { create(:user) }
  let(:category) { create(:category, name: "TestShopping", user: user) }
  let(:bbva_bank) { create(:bank, :bbva) }
  let(:nu_bank) { create(:bank, name: "Nu") }
  let(:bbva_tdc_account) { create(:bank_account, user: user, bank: bbva_bank, account_type: :credit) }
  let(:nu_account) { create(:bank_account, user: user, bank: nu_bank, account_type: :debit) }

  let(:ai_success_response) do
    {
      text: {
        amount: 179.0,
        description: "Amazon",
        merchant_name: nil,
        transaction_type: "variable_expense",
        date: nil,
        category_id: category.id,
        bank_account_id: nil,
        confidence: 0.92
      }.to_json,
      usage: {}
    }
  end

  before do
    category
    allow_any_instance_of(Ai::Client).to receive(:chat).and_return(ai_success_response)
  end

  describe "#call" do
    it "returns a success result with parsed fields" do
      result = described_class.call(text: "Gasté 179 en Amazon", user: user)

      expect(result).to be_success
      payload = result.payload
      expect(payload[:amount]).to eq(179.0)
      expect(payload[:description]).to eq("Amazon")
      expect(payload[:transaction_type]).to eq("variable_expense")
      expect(payload[:confidence]).to eq(0.92)
      expect(payload[:category_suggestion][:id]).to eq(category.id)
      expect(payload[:category_suggestion][:name]).to eq("TestShopping")
    end

    it "returns nil category_suggestion when AI returns null category_id" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        {
          text: {
            amount: 50.0,
            description: "Misc",
            transaction_type: "variable_expense",
            date: nil,
            category_id: nil,
            confidence: 0.5
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(text: "Pagué algo", user: user)
      expect(result).to be_success
      expect(result.payload[:category_suggestion]).to be_nil
    end

    it "returns nil category_suggestion when AI returns an unknown category_id" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        {
          text: {
            amount: 50.0,
            description: "Misc",
            transaction_type: "variable_expense",
            date: nil,
            category_id: 999_999,
            confidence: 0.5
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(text: "Pagué algo", user: user)
      expect(result).to be_success
      expect(result.payload[:category_suggestion]).to be_nil
    end

    it "parses date when present" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        {
          text: {
            amount: 100.0,
            description: "Store",
            transaction_type: "variable_expense",
            date: "2026-03-15",
            category_id: nil,
            confidence: 0.8
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(text: "Compré algo el 15 de marzo", user: user)
      expect(result).to be_success
      expect(result.payload[:date]).to eq("2026-03-15")
    end

    it "clamps confidence to 0.0–1.0" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        {
          text: {
            amount: 10.0,
            description: "Test",
            transaction_type: "income",
            date: nil,
            category_id: nil,
            confidence: 1.5
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(text: "test", user: user)
      expect(result.payload[:confidence]).to eq(1.0)
    end

    it "defaults to variable_expense for unknown transaction_type" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        {
          text: {
            amount: 10.0,
            description: "Test",
            transaction_type: "unknown_type",
            date: nil,
            category_id: nil,
            confidence: 0.5
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(text: "test", user: user)
      expect(result.payload[:transaction_type]).to eq("variable_expense")
    end

    it "returns failure when AI response is invalid JSON" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        { text: "not json at all", usage: {} }
      )

      result = described_class.call(text: "test", user: user)
      expect(result).to be_failure
    end

    it "returns failure when AI client raises an error" do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_raise(StandardError, "network error")

      result = described_class.call(text: "test", user: user)
      expect(result).to be_failure
    end

    context "with merchant and bank account extraction" do
      it "returns merchant and matched bank_account_id for BBVA TDC phrase" do
        bbva_tdc_account
        allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
          {
            text: {
              amount: 200.0,
              description: "Galletas",
              merchant_name: "Oxxo",
              transaction_type: "variable_expense",
              date: nil,
              category_id: nil,
              bank_account_id: bbva_tdc_account.id,
              confidence: 0.95
            }.to_json,
            usage: {}
          }
        )

        result = described_class.call(
          text: "gasté 200 pesos por galletas en el Oxxo con mi BBVA TDC",
          user: user
        )

        expect(result).to be_success
        expect(result.payload[:amount]).to eq(200.0)
        expect(result.payload[:merchant]).to eq("Oxxo")
        expect(result.payload[:bank_account_id]).to eq(bbva_tdc_account.id)
        expect(result.payload[:transaction_type]).to eq("variable_expense")
        expect(result.payload[:transcript]).to include("Oxxo")
      end

      it "returns transfer_out type and Nu account_id for Nu transfer phrase" do
        nu_account
        allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
          {
            text: {
              amount: 5000.0,
              description: "Transferencia",
              merchant_name: nil,
              transaction_type: "transfer_out",
              date: nil,
              category_id: nil,
              bank_account_id: nu_account.id,
              confidence: 0.9
            }.to_json,
            usage: {}
          }
        )

        result = described_class.call(
          text: "transferí 5000 a mi cuenta de Nu",
          user: user
        )

        expect(result).to be_success
        expect(result.payload[:transaction_type]).to eq("transfer_out")
        expect(result.payload[:bank_account_id]).to eq(nu_account.id)
        expect(result.payload[:merchant]).to be_nil
      end

      it "returns nil bank_account_id when phrase has no bank mention" do
        allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
          {
            text: {
              amount: 80.0,
              description: "Tacos",
              merchant_name: nil,
              transaction_type: "variable_expense",
              date: nil,
              category_id: nil,
              bank_account_id: nil,
              confidence: 0.85
            }.to_json,
            usage: {}
          }
        )

        result = described_class.call(text: "compré tacos por 80 pesos", user: user)

        expect(result).to be_success
        expect(result.payload[:amount]).to eq(80.0)
        expect(result.payload[:bank_account_id]).to be_nil
      end

      it "nullifies bank_account_id when AI returns an id not belonging to the user" do
        allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
          {
            text: {
              amount: 150.0,
              description: "Compra",
              merchant_name: nil,
              transaction_type: "variable_expense",
              date: nil,
              category_id: nil,
              bank_account_id: 999_999,
              confidence: 0.8
            }.to_json,
            usage: {}
          }
        )

        result = described_class.call(text: "pagué con BBVA TDC", user: user)

        expect(result).to be_success
        expect(result.payload[:bank_account_id]).to be_nil
      end

      it "includes transcript in the result payload" do
        text = "gasté 50 en la tienda"
        result = described_class.call(text: text, user: user)

        expect(result).to be_success
        expect(result.payload[:transcript]).to eq(text)
      end
    end
  end
end
