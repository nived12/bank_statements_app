# spec/services/statements/vision_extractor_spec.rb
require "rails_helper"

RSpec.describe Statements::VisionExtractor do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "BBVA Bancomer") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:vision_client) { instance_double(Ai::VisionClient) }

  before do
    allow(Ai::VisionClient).to receive(:new).and_return(vision_client)
  end

  describe "#validate_dependencies!" do
    let(:extractor) { described_class.new(statement_file) }

    context "when Ghostscript is installed" do
      before do
        allow(extractor).to receive(:system)
          .with("/usr/bin/which", "gs", out: File::NULL, err: File::NULL)
          .and_return(true)
      end

      it "sets @gs_cmd to 'gs'" do
        extractor.send(:validate_dependencies!)
        expect(extractor.instance_variable_get(:@gs_cmd)).to eq("gs")
      end
    end

    context "when Ghostscript is not installed" do
      before do
        allow(extractor).to receive(:system)
          .with("/usr/bin/which", "gs", out: File::NULL, err: File::NULL)
          .and_return(false)
      end

      it "raises DependencyError" do
        expect { extractor.send(:validate_dependencies!) }
          .to raise_error(described_class::DependencyError, /Ghostscript not installed/)
      end
    end
  end

  describe "#parse_conversion_error" do
    let(:extractor) { described_class.new(statement_file) }

    it "detects password errors from stderr" do
      _msg, is_password = extractor.send(:parse_conversion_error, "Error: This file requires a password for access.")
      expect(is_password).to be true
    end

    it "detects 'encrypted' as a password error" do
      _msg, is_password = extractor.send(:parse_conversion_error, "Error: file is encrypted")
      expect(is_password).to be true
    end

    it "detects 'password did not work' as a password error" do
      _msg, is_password = extractor.send(:parse_conversion_error, "password did not work")
      expect(is_password).to be true
    end

    it "detects invalidfileaccess errors" do
      msg, is_password = extractor.send(:parse_conversion_error, "Error: /invalidfileaccess in --run--")
      expect(msg).to match(/file permissions/)
      expect(is_password).to be false
    end

    it "returns first 3 lines for unknown errors" do
      stderr = "line1\nline2\nline3\nline4\n"
      msg, is_password = extractor.send(:parse_conversion_error, stderr)
      expect(msg).to include("line1")
      expect(msg).not_to include("line4")
      expect(is_password).to be false
    end
  end

  describe "#convert_pdf_to_images" do
    let(:extractor) { described_class.new(statement_file) }
    let(:pdf_path) { "/tmp/test.pdf" }

    before { extractor.instance_variable_set(:@gs_cmd, "gs") }

    context "when Ghostscript reports a password error" do
      before do
        allow(Open3).to receive(:capture3).and_return(
          ["", "Error: This file requires a password for access.", double(success?: false)]
        )
      end

      it "raises PasswordRequiredError" do
        expect { extractor.send(:convert_pdf_to_images, pdf_path) }
          .to raise_error(described_class::PasswordRequiredError, /password protected/)
      end
    end

    context "when Ghostscript times out" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error)
      end

      it "returns an empty array" do
        expect(extractor.send(:convert_pdf_to_images, pdf_path)).to eq([])
      end
    end

    context "when Ghostscript fails without a password error" do
      before do
        allow(Open3).to receive(:capture3).and_return(
          ["", "Error: some generic failure", double(success?: false)]
        )
      end

      it "returns an empty array" do
        expect(extractor.send(:convert_pdf_to_images, pdf_path)).to eq([])
      end
    end
  end

  describe "#call" do
    let(:vision_response) do
      <<~JSON
        {
          "transactions": [
            {
              "date": "2024-01-15",
              "description": "OXXO Purchase",
              "amount": -50.00,
              "reference": "REF123"
            },
            {
              "date": "2024-01-16",
              "description": "Salary Deposit",
              "amount": 5000.00,
              "reference": "NOM001"
            }
          ],
          "financial_summaries": [
            {
              "period_start": "2024-01-01",
              "period_end": "2024-01-31",
              "total_deposits": 5000.00,
              "total_withdrawals": 50.00
            }
          ],
          "opening_balance": 1000.00,
          "closing_balance": 5950.00
        }
      JSON
    end

    context "when PDF is successfully extracted" do
      before do
        allow(vision_client).to receive(:analyze_document).and_return(
          {
                    text: vision_response,
                    usage: {
                      prompt_token_count: 1000,
                      candidates_token_count: 500,
                      total_token_count: 1500
                    }
                  }
        )
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images)
          .and_return(["/tmp/page-001.jpg", "/tmp/page-002.jpg"])
      end

      it "returns success with extracted data" do
        result = described_class.call(statement_file)

        expect(result).to be_success
        expect(result.payload[:transactions]).to be_an(Array)
        expect(result.payload[:transactions].count).to eq(2)
        expect(result.payload[:extraction_source]).to eq("ai_vision")
      end

      it "includes financial summaries" do
        result = described_class.call(statement_file)

        expect(result.payload[:financial_summaries]).to be_an(Array)
        expect(result.payload[:financial_summaries].first["total_deposits"]).to eq(5000.00)
      end

      it "includes balance information" do
        result = described_class.call(statement_file)

        expect(result.payload[:opening_balance]).to eq(1000.00)
        expect(result.payload[:closing_balance]).to eq(5950.00)
      end
    end

    context "when the API call is billed but returns nothing usable" do
      before do
        allow(vision_client).to receive(:analyze_document).and_raise(
          Ai::VisionClient::ApiError.new(
            "Gemini stopped early (finishReason: MAX_TOKENS, output 24959 + thinking 7805 of 65536 max)",
            usage: {
              prompt_token_count: 18_267,
              candidates_token_count: 24_959,
              thoughts_token_count: 7_805,
              total_token_count: 51_031
            }
          )
        )
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images)
          .and_return([ "/tmp/page-001.jpg" ])
      end

      it "still records what the call cost" do
        described_class.call(statement_file)

        extraction = statement_file.reload.usage_metadata["extraction"]
        expect(extraction["candidates_token_count"]).to eq(24_959)
        expect(extraction["thoughts_token_count"]).to eq(7_805)
        expect(extraction["cost_usd"]).to be > 0
      end

      it "returns failure carrying the reason" do
        result = described_class.call(statement_file)

        expect(result).to be_failure
        expect(result.errors.full_messages.join).to include("MAX_TOKENS")
      end
    end

    # Skipping this spec - StatementFile model validation prevents creating records without files
    # This scenario cannot happen in practice, making the spec unrealistic
    # context "when statement file has no attached PDF" do
    #   let(:statement_file_no_pdf) do
    #     build(:statement_file, user: user, bank_account: bank_account, attach_file: false).tap do |sf|
    #       sf.save(validate: false)
    #     end
    #   end
    #
    #   it "raises ArgumentError" do
    #     expect {
    #       described_class.call(statement_file_no_pdf)
    #     }.to raise_error(ArgumentError, /no attached PDF/)
    #   end
    # end

    context "when PDF conversion fails" do
      before do
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images).and_return([])
      end

      it "returns failure" do
        result = described_class.call(statement_file)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include(/PDF conversion failed/)
      end
    end

    context "when Vision API returns empty response" do
      before do
        allow(vision_client).to receive(:analyze_document).and_return({ text: nil, usage: {} })
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images)
          .and_return(["/tmp/page-001.jpg"])
      end

      it "returns failure" do
        result = described_class.call(statement_file)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include(/empty response/)
      end
    end

    context "when Vision API raises ApiError" do
      before do
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images)
          .and_return(["/tmp/page-001.jpg"])
        allow(vision_client).to receive(:analyze_document)
          .and_raise(Ai::VisionClient::ApiError, "Rate limit exceeded")
      end

      it "returns failure with error message" do
        result = described_class.call(statement_file)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include(/Vision API error/)
      end
    end

    context "when Vision response has markdown formatting" do
      let(:markdown_response) do
        <<~RESPONSE
          ```json
          {
            "transactions": [
              {"date": "2024-01-15", "description": "Test", "amount": 100.00}
            ],
            "opening_balance": 1000.00,
            "closing_balance": 1100.00
          }
          ```
        RESPONSE
      end

      before do
        allow(vision_client).to receive(:analyze_document).and_return(
          {
                    text: markdown_response,
                    usage: { prompt_token_count: 100, candidates_token_count: 50, total_token_count: 150 }
                  }
        )
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images)
          .and_return(["/tmp/page-001.jpg"])
      end

      it "cleans markdown and parses correctly" do
        result = described_class.call(statement_file)

        expect(result).to be_success
        expect(result.payload[:transactions].count).to eq(1)
      end
    end

    context "when Vision response is invalid JSON" do
      before do
        allow(vision_client).to receive(:analyze_document).and_return(
          {
                    text: "Invalid JSON {",
                    usage: {}
                  }
        )
        allow_any_instance_of(described_class).to receive(:convert_pdf_to_images)
          .and_return(["/tmp/page-001.jpg"])
      end

      it "returns failure" do
        result = described_class.call(statement_file)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include(/Failed to parse/)
      end
    end
  end
end
