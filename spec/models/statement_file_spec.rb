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
end
