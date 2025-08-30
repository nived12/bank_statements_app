# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorHandling do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include ErrorHandling
    end
  end

  let(:test_instance) { test_class.new }
  let(:statement) { double("Statement", id: 123) }
  let(:error) { StandardError.new("Test error") }

  before do
    allow(statement).to receive(:update)
    allow(Rails.logger).to receive(:error)
    allow(error).to receive(:backtrace).and_return(["line1", "line2"])
  end

  describe "#handle_statement_error" do
    it "updates statement status to error" do
      expect(statement).to receive(:update).with(
        status: "error",
        processed_at: anything,
        error_message: "Statement processing failed: Test error"
      )

      test_instance.send(:handle_statement_error, statement, error)
    end

    it "logs error details" do
      expect(Rails.logger).to receive(:error).with("StatementIngestJob failed for statement 123: Test error")
      expect(Rails.logger).to receive(:error).with("line1\nline2")

      test_instance.send(:handle_statement_error, statement, error)
    end

    it "sets processed_at to current time" do
      travel_to Time.zone.local(2024, 1, 15, 12, 0, 0) do
        test_instance.send(:handle_statement_error, statement, error)
        
        expect(statement).to have_received(:update).with(
          hash_including(processed_at: Time.current)
        )
      end
    end
  end

  describe "#handle_pii_error" do
    it "updates statement status to error with PII specific message" do
      expect(statement).to receive(:update).with(
        status: "error",
        processed_at: anything,
        error_message: "PII redaction failed: Test error"
      )

      test_instance.send(:handle_pii_error, statement, error)
    end

    it "logs PII error" do
      expect(Rails.logger).to receive(:error).with("[PII] Redaction failed: Test error")

      test_instance.send(:handle_pii_error, statement, error)
    end
  end

  describe "#handle_financial_summary_error" do
    it "logs financial summary error" do
      expect(Rails.logger).to receive(:error).with("Failed to create financial summary: Test error")

      test_instance.send(:handle_financial_summary_error, error)
    end

    it "logs financial data when provided" do
      financial_data = { "balance" => 1000 }
      expect(Rails.logger).to receive(:error).with("Failed to create financial summary: Test error")
      expect(Rails.logger).to receive(:error).with("Financial data: {\"balance\"=>1000}")

      test_instance.send(:handle_financial_summary_error, error, financial_data)
    end

    it "does not log financial data when not provided" do
      expect(Rails.logger).to receive(:error).with("Failed to create financial summary: Test error")
      expect(Rails.logger).not_to receive(:error).with(/Financial data:/)

      test_instance.send(:handle_financial_summary_error, error)
    end
  end

  describe "#handle_ai_financial_summary_error" do
    it "logs AI financial summary error" do
      expect(Rails.logger).to receive(:error).with("Failed to create AI financial summary: Test error")

      test_instance.send(:handle_ai_financial_summary_error, error)
    end
  end
end
