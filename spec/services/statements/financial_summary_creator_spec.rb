# spec/services/statements/financial_summary_creator_spec.rb
require "rails_helper"

RSpec.describe Statements::FinancialSummaryCreator do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }

  describe "#call" do
    context "with valid summary data" do
      let(:summary_data) do
        {
          "opening_balance" => 1000.0,
          "closing_balance" => 1500.0,
          "start_date" => "2025-01-01",
          "end_date" => "2025-01-31",
          "total_deposits" => 2000.0,
          "total_withdrawals" => 1500.0,
          "total_commissions" => 10.0,
          "total_fees" => 5.0
        }
      end

      it "creates a financial summary" do
        expect { described_class.call(statement_file, summary_data) }
          .to change { StatementFinancialSummary.count }.by(1)
      end

      it "returns success" do
        result = described_class.call(statement_file, summary_data)

        expect(result).to be_success
      end

      it "sets correct attributes" do
        result = described_class.call(statement_file, summary_data)
        summary = result.payload

        expect(summary.initial_balance).to eq(1000.0)
        expect(summary.final_balance).to eq(1500.0)
        expect(summary.statement_period_start).to eq(Date.new(2025, 1, 1))
        expect(summary.statement_period_end).to eq(Date.new(2025, 1, 31))
        expect(summary.days_in_period).to eq(31)
        expect(summary.total_commissions).to eq(10.0)
        expect(summary.total_fees).to eq(5.0)
      end

      it "sets statement_type_data for savings account" do
        result = described_class.call(statement_file, summary_data)
        summary = result.payload

        expect(summary.statement_type_data["total_deposits"]).to eq(2000.0)
        expect(summary.statement_type_data["total_withdrawals"]).to eq(1500.0)
      end
    end

    context "with credit card account" do
      let(:credit_account) { create(:bank_account, user: user, bank: bank, account_type: "credit") }
      let(:credit_statement) { create(:statement_file, user: user, bank_account: credit_account) }
      let(:summary_data) do
        {
          "opening_balance" => 5000.0,
          "closing_balance" => 3000.0,
          "start_date" => "2025-01-01",
          "end_date" => "2025-01-31",
          "total_deposits" => 2500.0,
          "total_withdrawals" => 500.0,
          "minimum_payment" => 150.0,
          "credit_limit" => 10000.0
        }
      end

      it "sets credit-specific statement_type_data" do
        result = described_class.call(credit_statement, summary_data)
        summary = result.payload

        expect(summary.statement_type).to eq("credit")
        expect(summary.statement_type_data["total_payments"]).to eq(2500.0)
        expect(summary.statement_type_data["total_charges"]).to eq(500.0)
        expect(summary.statement_type_data["minimum_payment"]).to eq(150.0)
        expect(summary.statement_type_data["credit_limit"]).to eq(10000.0)
      end
    end

    context "with minimal data" do
      let(:summary_data) do
        {
          "start_date" => "2025-01-01",
          "end_date" => "2025-01-31"
        }
      end

      it "creates summary with defaults" do
        result = described_class.call(statement_file, summary_data)

        expect(result).to be_success
        summary = result.payload
        expect(summary.initial_balance).to eq(0.0)
        expect(summary.final_balance).to eq(0.0)
        expect(summary.statement_type).to eq("savings")
      end
    end

    context "with different date formats" do
      it "parses ISO format (YYYY-MM-DD)" do
        summary_data = { "start_date" => "2025-01-15", "end_date" => "2025-02-15" }
        result = described_class.call(statement_file, summary_data)

        expect(result.payload.statement_period_start).to eq(Date.new(2025, 1, 15))
        expect(result.payload.statement_period_end).to eq(Date.new(2025, 2, 15))
      end

      it "parses DD/MM/YYYY format" do
        summary_data = { "start_date" => "15/01/2025", "end_date" => "15/02/2025" }
        result = described_class.call(statement_file, summary_data)

        expect(result.payload.statement_period_start).to eq(Date.new(2025, 1, 15))
        expect(result.payload.statement_period_end).to eq(Date.new(2025, 2, 15))
      end

      it "handles Date objects" do
        summary_data = { "start_date" => Date.new(2025, 1, 15), "end_date" => Date.new(2025, 2, 15) }
        result = described_class.call(statement_file, summary_data)

        expect(result.payload.statement_period_start).to eq(Date.new(2025, 1, 15))
        expect(result.payload.statement_period_end).to eq(Date.new(2025, 2, 15))
      end

      it "handles missing dates with failure when no fallback dates are available" do
        # Create a statement_file with cutoff_date (required by validation)
        # but ensure no transactions exist and stub fallback methods
        summary_data = { "start_date" => nil, "end_date" => nil }

        # Ensure statement_file has no transactions
        statement_file.transactions.destroy_all

        # Stub the fallback methods to return nil via allow_any_instance_of
        allow_any_instance_of(described_class).to receive(:fallback_period_start).and_return(nil)
        allow_any_instance_of(described_class).to receive(:fallback_period_end).and_return(nil)

        result = described_class.call(statement_file, summary_data)

        # Service should fail when dates are nil and no fallback dates are available
        expect(result).to be_failure
        expect(result.errors.full_messages).to include(match(/Cannot determine statement period dates/))
      end
    end

    context "with explicit statement_type" do
      let(:summary_data) do
        {
          "opening_balance" => 100.0,
          "start_date" => "2025-01-01",
          "end_date" => "2025-01-31"
        }
      end

      it "uses provided statement_type" do
        result = described_class.call(statement_file, summary_data, "credit")

        expect(result).to be_success
        expect(result.payload.statement_type).to eq("credit")
      end
    end

    context "when creation fails" do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(StatementFinancialSummary.new))
      end

      it "returns failure" do
        result = described_class.call(statement_file, {})

        expect(result).to be_failure
      end
    end
  end
end
