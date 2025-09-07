# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiiHandlingConcern do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include PiiHandlingConcern
      include Configurable
    end
  end

  let(:test_instance) { test_class.new }
  let(:statement) { double("Statement") }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe "#restore_pii_tokens" do
    context "when PII redaction is not enabled" do
      before do
        allow(test_instance).to receive(:pii_redaction_enabled?).and_return(false)
      end

      it "returns original data when no redaction HMAC" do
        allow(statement).to receive(:redaction_hmac).and_return(nil)

        result = test_instance.send(:restore_pii_tokens, { "data" => "test" }, statement)

        expect(result).to eq({ "data" => "test" })
      end

      it "returns original data when no redaction map" do
        allow(statement).to receive(:redaction_hmac).and_return("hmac123")
        allow(statement).to receive(:redaction_map).and_return(nil)

        result = test_instance.send(:restore_pii_tokens, { "data" => "test" }, statement)

        expect(result).to eq({ "data" => "test" })
      end
    end

    context "when PII redaction is enabled" do
      let(:redaction_map) { { "TOKEN_1" => "John Doe", "TOKEN_2" => "123-45-6789" } }
      let(:parsed_data) { { "name" => "TOKEN_1", "ssn" => "TOKEN_2" } }

      before do
        allow(statement).to receive(:redaction_hmac).and_return("hmac123")
        allow(statement).to receive(:redaction_map).and_return(redaction_map)
        allow(test_instance).to receive(:pii_redaction_enabled?).and_return(true)
      end

      it "restores tokens from the map" do
        result = test_instance.send(:restore_pii_tokens, parsed_data, statement)

        expect(result["name"]).to eq("John Doe")
        expect(result["ssn"]).to eq("123-45-6789")
      end

      it "logs the restoration process" do
        test_instance.send(:restore_pii_tokens, parsed_data, statement)

        expect(Rails.logger).to have_received(:info).with("[PII] Token restoration completed")
      end

      it "preserves non-token values" do
        parsed_data["amount"] = "100.00"

        result = test_instance.send(:restore_pii_tokens, parsed_data, statement)

        expect(result["amount"]).to eq("100.00")
      end
    end

    context "when restoration fails" do
      before do
        allow(statement).to receive(:redaction_hmac).and_return("hmac123")
        allow(statement).to receive(:redaction_map).and_return({ "TOKEN" => "value" })
        allow(test_instance).to receive(:pii_redaction_enabled?).and_return(true)
        allow(test_instance).to receive(:restore_tokens_deep).and_raise(StandardError, "Restoration failed")
      end

      it "raises a runtime error with descriptive message" do
        expect {
          test_instance.send(:restore_pii_tokens, { "data" => "test" }, statement)
        }.to raise_error(RuntimeError, "PII token restoration failed: Restoration failed")
      end

      it "logs the error" do
        expect {
          test_instance.send(:restore_pii_tokens, { "data" => "test" }, statement)
        }.to raise_error(RuntimeError)

        expect(Rails.logger).to have_received(:error).with("[PII] Token restoration error: Restoration failed")
      end
    end
  end

  describe "#restore_tokens_deep" do
    let(:redaction_map) { { "TOKEN_1" => "John Doe", "TOKEN_2" => "123-45-6789" } }

    context "with Hash objects" do
      it "restores tokens in nested hashes" do
        input = { "user" => { "name" => "TOKEN_1", "ssn" => "TOKEN_2" } }

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result["user"]["name"]).to eq("John Doe")
        expect(result["user"]["ssn"]).to eq("123-45-6789")
      end

      it "preserves non-token values in hashes" do
        input = { "name" => "TOKEN_1", "amount" => "100.00" }

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result["name"]).to eq("John Doe")
        expect(result["amount"]).to eq("100.00")
      end
    end

    context "with Array objects" do
      it "restores tokens in arrays" do
        input = [ "TOKEN_1", "TOKEN_2", "normal text" ]

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result[0]).to eq("John Doe")
        expect(result[1]).to eq("123-45-6789")
        expect(result[2]).to eq("normal text")
      end

      it "restores tokens in nested arrays" do
        input = [ [ "TOKEN_1" ], [ "TOKEN_2" ] ]

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result[0][0]).to eq("John Doe")
        expect(result[1][0]).to eq("123-45-6789")
      end
    end

    context "with String objects" do
      it "restores tokens in strings" do
        input = "Hello TOKEN_1, your SSN is TOKEN_2"

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result).to eq("Hello John Doe, your SSN is 123-45-6789")
      end

      it "handles strings with no tokens" do
        input = "Hello world"

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result).to eq("Hello world")
      end

      it "handles strings with partial tokens" do
        input = "Hello TOKEN_1, how are you?"

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result).to eq("Hello John Doe, how are you?")
      end
    end

    context "with other object types" do
      it "returns non-string objects unchanged" do
        input = 123

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result).to eq(123)
      end

      it "returns nil unchanged" do
        result = test_instance.send(:restore_tokens_deep, nil, redaction_map)

        expect(result).to be_nil
      end

      it "returns boolean values unchanged" do
        result = test_instance.send(:restore_tokens_deep, true, redaction_map)

        expect(result).to be true
      end
    end

    context "with complex nested structures" do
      it "restores tokens in deeply nested structures" do
        input = {
          "users" => [
            { "name" => "TOKEN_1", "details" => { "ssn" => "TOKEN_2" } },
            { "name" => "Jane", "details" => { "ssn" => "987-65-4321" } }
          ],
          "metadata" => "TOKEN_1 processed"
        }

        result = test_instance.send(:restore_tokens_deep, input, redaction_map)

        expect(result["users"][0]["name"]).to eq("John Doe")
        expect(result["users"][0]["details"]["ssn"]).to eq("123-45-6789")
        expect(result["users"][1]["name"]).to eq("Jane")
        expect(result["users"][1]["details"]["ssn"]).to eq("987-65-4321")
        expect(result["metadata"]).to eq("John Doe processed")
      end
    end
  end
end
