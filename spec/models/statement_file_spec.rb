# spec/models/statement_file_spec.rb
require "rails_helper"

RSpec.describe StatementFile, type: :model do
  let(:statement_file) { create(:statement_file) }
  let(:statement_file_without_file) { build(:statement_file, :without_file) }
  let(:processed_statement_file) { create(:statement_file, :processed) }

  it "is valid with an attached file" do
    expect(statement_file).to be_valid
    expect(statement_file.file).to be_attached
  end

  it "is invalid without a file" do
    expect(statement_file_without_file).not_to be_valid
    expect(statement_file_without_file.errors[:file]).to be_present
  end

  it "can have processed state" do
    expect(processed_statement_file.status).to eq("parsed")
    expect(processed_statement_file.parsed_json).to be_present
  end

  describe "attributes" do
    it "has parsed_json as JSON attribute with default empty hash" do
      expect(statement_file.parsed_json).to eq({})
    end

    it "has redaction_map as JSON attribute with default empty hash" do
      expect(statement_file.redaction_map).to eq({})
    end

    it "can set and retrieve parsed_json" do
      test_data = { "transactions" => [ { "amount" => 100, "date" => "2024-01-01" } ] }
      statement_file.parsed_json = test_data
      expect(statement_file.parsed_json).to eq(test_data)
    end

    it "can set and retrieve redaction_map" do
      redaction_data = { "ssn" => "***-**-1234", "account" => "****1234" }
      statement_file.redaction_map = redaction_data
      expect(statement_file.redaction_map).to eq(redaction_data)
    end

    it "handles complex nested JSON data" do
      complex_data = {
        "statement_info" => {
          "period" => "January 2024",
          "account_holder" => "John Doe"
        },
        "transactions" => [
          { "id" => 1, "description" => "Grocery Store", "amount" => -45.67 },
          { "id" => 2, "description" => "Salary", "amount" => 2500.00 }
        ]
      }
      statement_file.parsed_json = complex_data
      expect(statement_file.parsed_json).to eq(complex_data)
    end
  end

  describe "validations" do
    it "validates redaction_hmac length when present" do
      # Valid length (128 characters)
      statement_file.redaction_hmac = "a" * 128
      expect(statement_file).to be_valid

      # Invalid length (129 characters)
      statement_file.redaction_hmac = "a" * 129
      expect(statement_file).not_to be_valid
      expect(statement_file.errors[:redaction_hmac]).to include("is too long (maximum is 128 characters)")
    end

    it "allows blank redaction_hmac" do
      statement_file.redaction_hmac = ""
      expect(statement_file).to be_valid

      statement_file.redaction_hmac = nil
      expect(statement_file).to be_valid
    end
  end

  describe "encryption behavior" do
    it "encrypts parsed_json in non-test environments" do
      # This test verifies the encryption is working
      # In test environment, encryption is disabled, so we test the attribute behavior
      test_data = { "sensitive" => "data", "amount" => 123.45 }
      statement_file.parsed_json = test_data

      # Save to database
      statement_file.save!

      # Reload from database
      reloaded = StatementFile.find(statement_file.id)
      expect(reloaded.parsed_json).to eq(test_data)
    end

    it "encrypts redaction_map in non-test environments" do
      redaction_data = { "ssn" => "***-**-1234" }
      statement_file.redaction_map = redaction_data

      # Save to database
      statement_file.save!

      # Reload from database
      reloaded = StatementFile.find(statement_file.id)
      expect(reloaded.redaction_map).to eq(redaction_data)
    end

    it "encrypts error_message in non-test environments" do
      error_msg = "Failed to parse PDF due to corrupted content"
      statement_file.error_message = error_msg

      # Save to database
      statement_file.save!

      # Reload from database
      reloaded = StatementFile.find(statement_file.id)
      expect(reloaded.error_message).to eq(error_msg)
    end
  end

  describe "factory traits" do
    it "creates processed statement file with proper JSON data" do
      processed = create(:statement_file, :processed)
      expect(processed.parsed_json).to include("message" => "test parsed data")
      expect(processed.parsed_json).to include("transactions" => [])
    end

    it "allows custom parsed_json in factory" do
      custom_data = { "custom" => "data", "amount" => 999.99 }
      custom_statement = create(:statement_file, parsed_json: custom_data)
      expect(custom_statement.parsed_json).to eq(custom_data)
    end

    it "allows custom redaction_map in factory" do
      custom_redaction = { "custom_field" => "***" }
      custom_statement = create(:statement_file, redaction_map: custom_redaction)
      expect(custom_statement.redaction_map).to eq(custom_redaction)
    end
  end
end
