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
  let(:error) { StandardError.new("Test error") }

  before do
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:info)
    allow(error).to receive(:backtrace).and_return([ "line1", "line2" ])
  end



  describe "#log_error" do
    it "logs error with context and data" do
      expect(Rails.logger).to receive(:error).with("[Test context] Test error")
      expect(Rails.logger).to receive(:error).with("line1\nline2")
      expect(Rails.logger).to receive(:error).with("Context data: {:key=>\"value\"}")

      test_instance.send(:log_error, error, context: "Test context", data: { key: "value" })
    end

    it "logs error without context and data" do
      expect(Rails.logger).to receive(:error).with("Test error")
      expect(Rails.logger).to receive(:error).with("line1\nline2")

      test_instance.send(:log_error, error)
    end

    it "logs warning level" do
      expect(Rails.logger).to receive(:warn).with("[Test context] Test error")

      test_instance.send(:log_error, error, context: "Test context", level: :warn)
    end

    it "logs info level" do
      expect(Rails.logger).to receive(:info).with("[Test context] Test error")

      test_instance.send(:log_error, error, context: "Test context", level: :info)
    end
  end
end
