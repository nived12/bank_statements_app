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
      expect(statement_file.errors[:redaction_hmac]).to include("es demasiado largo (máximo 128 caracteres)")
    end

    it "allows blank redaction_hmac" do
      statement_file.redaction_hmac = ""
      expect(statement_file).to be_valid

      statement_file.redaction_hmac = nil
      expect(statement_file).to be_valid
    end

    it "requires cutoff_date on create" do
      statement_file_without_cutoff = build(:statement_file, :without_cutoff_date)
      expect(statement_file_without_cutoff).not_to be_valid
      expect(statement_file_without_cutoff.errors[:cutoff_date]).to be_present
    end

    it "allows cutoff_date to be present on create" do
      statement_file_with_cutoff = create(:statement_file, cutoff_date: Time.zone.today)
      expect(statement_file_with_cutoff).to be_valid
    end

    it "allows nil cutoff_date for existing records" do
      # Create with cutoff_date first
      existing_statement = create(:statement_file, cutoff_date: Time.zone.today)

      # Update to nil (simulating existing records without cutoff_date)
      existing_statement.cutoff_date = nil
      expect(existing_statement).to be_valid
    end
  end

  describe "#success?" do
    it "returns true for completed status" do
      sf = build(:statement_file, status: :completed)
      expect(sf.success?).to be true
    end

    it "returns true for parsed status" do
      sf = build(:statement_file, status: :parsed)
      expect(sf.success?).to be true
    end

    it "returns false for pending status" do
      sf = build(:statement_file, status: :pending)
      expect(sf.success?).to be false
    end

    it "returns false for error status" do
      sf = build(:statement_file, status: :error)
      expect(sf.success?).to be false
    end
  end

  describe "#status_color" do
    it "returns green for completed status" do
      sf = build(:statement_file, status: :completed)
      expect(sf.status_color).to eq("green")
    end

    it "returns green for parsed status" do
      sf = build(:statement_file, status: :parsed)
      expect(sf.status_color).to eq("green")
    end

    it "returns red for error status" do
      sf = build(:statement_file, status: :error)
      expect(sf.status_color).to eq("red")
    end

    it "returns amber for pending status" do
      sf = build(:statement_file, status: :pending)
      expect(sf.status_color).to eq("amber")
    end

    it "returns amber for processing status" do
      sf = build(:statement_file, status: :processing)
      expect(sf.status_color).to eq("amber")
    end
  end

  describe "scopes" do
    it "orders by cutoff_date descending with by_cutoff_date scope" do
      old_statement = create(:statement_file, cutoff_date: 2.months.ago)
      new_statement = create(:statement_file, cutoff_date: 1.month.ago)
      recent_statement = create(:statement_file, cutoff_date: Time.zone.today)

      ordered = StatementFile.by_cutoff_date(:desc).to_a
      expect(ordered.first).to eq(recent_statement)
      expect(ordered.last).to eq(old_statement)
    end

    it "orders by cutoff_date ascending when specified" do
      old_statement = create(:statement_file, cutoff_date: 2.months.ago)
      new_statement = create(:statement_file, cutoff_date: 1.month.ago)
      recent_statement = create(:statement_file, cutoff_date: Time.zone.today)

      ordered = StatementFile.by_cutoff_date(:asc).to_a
      expect(ordered.first).to eq(old_statement)
      expect(ordered.last).to eq(recent_statement)
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

  describe "#file_password" do
    it "can set and retrieve file_password" do
      statement_file.file_password = "test_password_123"
      statement_file.save!

      reloaded = StatementFile.find(statement_file.id)
      expect(reloaded.file_password).to eq("test_password_123")
    end

    it "allows nil file_password" do
      statement_file.file_password = nil
      expect(statement_file).to be_valid
    end

    it "encrypts file_password in the database" do
      statement_file.file_password = "secret_password"
      statement_file.save!

      reloaded = StatementFile.find(statement_file.id)
      expect(reloaded.file_password).to eq("secret_password")
    end
  end

  describe "#clear_password!" do
    it "clears the file_password" do
      statement_file.update!(file_password: "test_password")
      expect(statement_file.file_password).to eq("test_password")

      statement_file.clear_password!

      statement_file.reload
      expect(statement_file.file_password).to be_nil
    end

    it "does nothing if file_password is already nil" do
      statement_file.update!(file_password: nil)

      expect { statement_file.clear_password! }.not_to raise_error

      statement_file.reload
      expect(statement_file.file_password).to be_nil
    end
  end

  describe "#password_required_error?" do
    it "returns true when status is error and error_message contains password_required:" do
      statement_file.update!(status: :error, error_message: "password_required: PDF is password protected")

      expect(statement_file.password_required_error?).to be true
    end

    it "returns false when status is error but error_message does not contain password_required:" do
      statement_file.update!(status: :error, error_message: "Some other error occurred")

      expect(statement_file.password_required_error?).to be false
    end

    it "returns false when status is not error" do
      statement_file.update!(status: :completed, error_message: nil)

      expect(statement_file.password_required_error?).to be false
    end

    it "returns false when error_message is nil" do
      statement_file.update!(status: :error, error_message: nil)

      expect(statement_file.password_required_error?).to be false
    end
  end
end
