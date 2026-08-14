require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  let!(:user) { create(:user) }
  let!(:bbva_bank) do
    Bank.find_or_create_by(code: "bbva") do |b|
      b.name = "BBVA Bancomer"; b.supported_type = 'both'; b.active = true
    end
  end
  let!(:bank_account) do
    create(
      :bank_account,
      user: user,
      bank: bbva_bank,
      account_number: "1234",
      currency: "MXN",
      opening_balance: 0.0,
      account_type: "debit"  # Explicitly set to debit to use BbvaSavingsAccount parser
    )
  end

  let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :text_with_ai) }

  subject(:perform_job) { described_class.perform_now(statement_file.id) }

  before do
    setup_environment_variables
    setup_text_extraction
  end

  describe "#perform" do
    context "when AI API is available" do
      before do
        # Use vision_ai strategy to test vision extraction path
        statement_file.update!(processing_strategy: :vision_ai)
        setup_orchestrator_mocks
        setup_importer_mocks
      end

      it "successfully processes statement with AI enhancement" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq("completed")
        # The extraction source is now determined by Vision-based extraction
        expect(statement_file.parsed_json["extraction_source"]).to eq("ai_vision")

        transaction = statement_file.parsed_json["transactions"].first
        expect(transaction["transaction_type"]).to eq("income")
        expect(transaction["amount"]).to eq(15000.0)
      end
    end

    context "when PII redaction is enabled" do
      before do
        allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("1")
        allow(TextExtractor).to receive(:extract_text_layer)
          .and_return("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
        setup_orchestrator_mocks_for_pii
        setup_importer_mocks
      end

      context "when redaction data exists" do
        before do
          # Pre-populate redaction map that matches the Vision response tokens
          redaction_map = { "⟪PII:EMAIL:1⟫" => "juan.perez@example.com" }
          statement_file.update!(redaction_map: redaction_map, redaction_hmac: "test_hmac")
        end

        it "persists redaction_map and redaction_hmac" do
          perform_job
          statement_file.reload

          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
        end

        it "restores PII tokens from AI output" do
          perform_job
          statement_file.reload

          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
          expect(statement_file.parsed_json.dig("transactions", 0, "description"))
            .to eq("Payment from juan.perez@example.com")
        end

        it "processes successfully with PII enabled" do
          perform_job
          statement_file.reload

          expect(statement_file.status).to eq("completed")
        end

        it "creates consistent redaction data for same text" do
          # First run creates redaction data
          perform_job
          statement_file.reload
          first_hmac = statement_file.redaction_hmac

          # Second run should use existing redaction data
          described_class.perform_now(statement_file.id)
          statement_file.reload
          second_hmac = statement_file.redaction_hmac

          # HMACs should be the same since the text and redaction process are identical
          expect(first_hmac).to eq(second_hmac)
          expect(statement_file.status).to eq("completed")
        end
      end

      context "when no redaction data exists" do
        before do
          statement_file.update!(redaction_map: nil, redaction_hmac: nil)

          # Use Text + AI path (which handles PII redaction/restoration)
          allow(TextExtractor).to receive(:valid_text?).and_return(true)

          # Allow real PiiHandler.redact_text to run and create redaction map
          # It will detect PII in the text and create the map
          allow(Statements::PiiHandler).to receive(:redact_text).and_call_original

          # Mock Ai::PostProcessor to return extracted transactions
          ai_result = ApplicationService::Response.new(
            success: true,
            payload: {
              "transactions" => [
                {
                  "date" => "2025-08-01",
                  "description" => "Payment from juan.perez@example.com",
                  "amount" => 1200.0,
                  "transaction_type" => "income"
                }
              ],
              "financial_summaries" => [],
              "opening_balance" => 0.0,
              "closing_balance" => 1200.0,
              "extraction_source" => "ai_post_processor_text"
            },
            errors: nil
          )
          allow(Ai::PostProcessor).to receive(:call).and_return(ai_result)

          # Mock PiiHandler.restore to pass through data
          allow(Statements::PiiHandler).to receive(:restore) do |_sf, data|
            ApplicationService::Response.new(success: true, payload: data, errors: nil)
          end

          # Mock Importer to avoid creating real transactions
          allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(
            ApplicationService::Response.new(
              success: true,
              payload: { duplicates_found: false },
              errors: nil
            )
          )

          # Mock FinancialSummaryCreator
          allow(Statements::FinancialSummaryCreator).to receive(:call)
        end

        it "creates new redaction map and processes successfully" do
          perform_job
          statement_file.reload

          expect(statement_file.status).to eq("completed")
          # PiiHandler.redact_text creates the redaction map when it runs
          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
        end
      end
    end

    context "when PII redaction is disabled" do
      before do
        allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return(nil)
        setup_orchestrator_mocks
        setup_importer_mocks
      end

      it "does not persist redaction_map or redaction_hmac" do
        perform_job
        statement_file.reload

        expect(statement_file.redaction_map).to be_nil.or be_empty
        expect(statement_file.redaction_hmac).to be_nil.or be_empty
      end
    end
  end

  context "transaction relevance with opening balance dates" do
    let(:opening_balance_date) { Date.new(2025, 1, 15) }
    let!(:bank_account_with_date) do
      create(
        :bank_account,
        bank: bbva_bank,
        account_number: "5678",
        currency: "MXN",
        opening_balance: 1000.0,
        opening_balance_date: opening_balance_date
      )
    end

    let!(:statement_file_with_date) { create(:statement_file, bank_account: bank_account_with_date, processing_strategy: :vision_ai) }

    before do
      # Mock VisionExtractor to return transactions around opening date
      vision_result = ApplicationService::Response.new(
        success: true,
        payload: {
          transactions: build_transactions_around_opening_date["transactions"].map { |t| t.transform_keys(&:to_s) },
          financial_summaries: [],
          opening_balance: 1000.0,
          closing_balance: 1200.0,
          extraction_source: "ai_vision"
        },
        errors: nil
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(vision_result)

      # Mock PiiHandler to pass through data unchanged (but properly formatted)
      allow_any_instance_of(Statements::PiiHandler).to receive(:call) do |instance|
        # Get the original data before deep_symbolize_keys was applied
        # We need to return symbol keys for the payload structure
        data = instance.instance_variable_get(:@data)
        ApplicationService::Response.new(
          success: true,
          payload: data,
          errors: nil
        )
      end

      allow(Statements::PiiHandler).to receive(:restore) do |_sf, data|
        # Keep data structure as-is
        ApplicationService::Response.new(
          success: true,
          payload: data,
          errors: nil
        )
      end

      # Mock FinancialSummaryCreator
      allow(Statements::FinancialSummaryCreator).to receive(:call)

      # Note: Transactions::Categorizer is no longer called separately -
      # categorization is included in the AI extraction call

      # Allow real importer to run - don't mock it
      # Mock duplicate detector to return no duplicates
      allow(Transactions::DuplicateDetector).to receive(:call).and_return(
        ApplicationService::Response.new(
          success: true,
          payload: [],
          errors: nil
        )
      )
    end

    it "imports transactions respecting opening balance date relevance" do
      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      expect(statement_file_with_date.status).to eq("completed")
      expect(statement_file_with_date.transactions.count).to eq(3)

      # Check that transactions are properly classified by relevance
      relevant_transactions = statement_file_with_date.transactions.relevant_for_balance(opening_balance_date)
      historical_transactions = statement_file_with_date.transactions.historical(opening_balance_date)

      # opening_balance is the figure at the END of opening_balance_date, so that
      # day's activity is already inside it and counts as historical.
      expect(relevant_transactions.count).to eq(1)
      expect(historical_transactions.count).to eq(2)

      # Verify specific transaction dates and relevance
      relevant_dates = relevant_transactions.pluck(:date).sort
      historical_dates = historical_transactions.pluck(:date).sort

      expect(relevant_dates).to eq([ opening_balance_date + 5.days ])
      expect(historical_dates).to eq([ opening_balance_date - 5.days, opening_balance_date ])
    end

    it "maintains transaction data integrity during import" do
      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      transaction = statement_file_with_date.transactions.find_by(date: opening_balance_date)
      expect(transaction).to be_present
      expect(transaction.description).to eq("Transaction on opening balance date")
      expect(transaction.amount).to eq(100.0)
      expect(transaction.relevant_for_balance?).to be false
    end

    it "handles edge case of transactions exactly on opening balance date" do
      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      edge_case_transaction = statement_file_with_date.transactions.find_by(date: opening_balance_date)
      expect(edge_case_transaction).to be_present
      expect(edge_case_transaction.relevant_for_balance?).to be false
      expect(edge_case_transaction.historical?).to be true
    end
  end

  context "with BBVA credit card statements" do
    let(:bbva_bank) { Bank.find_by(code: "bbva") }
    let(:bank_account) do
      create(
        :bank_account,
        bank: bbva_bank,
        account_number: "1234",
        currency: "MXN",
        opening_balance: 0.0,
        account_type: "credit"
      )
    end

    let(:statement_file) { create(:statement_file, bank_account: bank_account) }

    context "with new BBVA format (July 2024+)" do
      before do
        allow(TextExtractor).to receive(:extract_text_layer).and_return(
          <<~TEXT
            BBVA
            Número de cuenta: XXXXXX9496

            RESUMEN DE CARGOS Y ABONOS DEL PERIODO
            Adeudo del periodo anterior: $54,538.87
            Cargos regulares (no a meses): + $48,351.03
            Pagos y abonos: - $54,538.87

            CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
            Tarjeta titular: XXXXXXXXXXXX9496

            21-jun-2025  23-jun-2025  TST*THE WINDOW - HOLLYWO  +$193.20
            21-jun-2025  23-jun-2025  HOLLYWOOD 21 MARKET       +$500.73
            21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$348.21
            21-jun-2025  23-jun-2025  RAISING CANES 0387        +$409.07
            21-jun-2025  23-jun-2025  ROSS STORES N414          +$2,323.03

            TOTAL CARGOS: $85,591.03
            TOTAL ABONOS: -$54,538.87
          TEXT
        )
        allow(TextExtractor).to receive(:valid_text?).and_return(true)
        setup_environment_variables
        setup_orchestrator_mocks_for_bbva_credit
        setup_importer_mocks
      end

      it "successfully processes new BBVA format with deterministic parser" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        # Parser-first approach: uses deterministic parser when available
        expect(statement_file.parsed_json['extraction_source']).to eq('deterministic_parser')
        expect(statement_file.parsed_json['transactions']).to be_present
      end

      it "extracts transactions from credit card statement" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('deterministic_parser')
        transactions = statement_file.parsed_json['transactions']
        expect(transactions).to be_an(Array)
      end
    end

    context "with legacy BBVA format (pre-July 2024)" do
      before do
        # Use parser_only strategy to test deterministic parser
        statement_file.update!(processing_strategy: :parser_only)
        allow(TextExtractor).to receive(:extract_text_layer).and_return(
          <<~TEXT
            BBVA
            Número de cuenta: XXXXXX9496

            Movimientos Efectuados
            Tarjeta Titular 1234 5678 9012 3456

            FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
            15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | ABC123456789 | 123456789 | 348.21 |#{" "}
            15/06/25 | 17/06/25 | HEB VALLE ALTO | DEF987654321 | 987654321 | 1,166.00 |#{" "}
            15/06/25 | 17/06/25 | PAGO TARJETA CREDITO | | | | 500.00

            TOTAL IMPORTES
          TEXT
        )
        allow(TextExtractor).to receive(:valid_text?).and_return(true)
        setup_environment_variables
        setup_importer_mocks
      end

      it "successfully processes legacy BBVA format with deterministic parser" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        # Parser-first approach: uses deterministic parser when available
        expect(statement_file.parsed_json['extraction_source']).to eq('standard_parser')
        expect(statement_file.parsed_json['transactions']).to be_present
      end
    end

    context "with format detection edge cases" do
      before do
        # Use parser_only strategy to test deterministic parser
        statement_file.update!(processing_strategy: :parser_only)
        setup_environment_variables
        setup_importer_mocks
      end

      it "processes statements with ambiguous format using deterministic parser" do
        allow(TextExtractor).to receive(:extract_text_layer).and_return(
          <<~TEXT
            BBVA
            Número de cuenta: XXXXXX9496

            Some generic text that doesn't match either format

            15/06/25 STARBUCKS STORE 05775 348.21
            21-jun-2025 STARBUCKS STORE 05775 +$348.21
          TEXT
        )
        allow(TextExtractor).to receive(:valid_text?).and_return(true)

        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        # Parser-first approach: deterministic parser handles the format
        expect(statement_file.parsed_json['extraction_source']).to eq('standard_parser')
        expect(statement_file.parsed_json).to be_present
      end
    end
  end

  private

  def setup_environment_variables
    # Set up and_call_original first, then override specific keys.
    # :fetch needs it too — Ai::VisionClient reads GEMINI_MAX_OUTPUT_TOKENS in
    # its class body, so an unlisted fetch raises when the constant autoloads.
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
    allow(ENV).to receive(:fetch).with("TRIAL_DURATION_DAYS", 30).and_return(30)
    allow(ENV).to receive(:[]).with("AI_API_KEY").and_return("fake_key")
    allow(ENV).to receive(:[]).with("AI_PROVIDER").and_return(nil)
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("gemini-2.0-flash-lite")
    allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("0")
    allow(ENV).to receive(:[]).with("USE_VISION_PROCESSOR").and_return(nil)

    # CRITICAL: Mock all AI clients to prevent real API calls
    vision_response = build_vision_json_response
    allow(Ai::VisionClient).to receive(:new).and_return(
      instance_double(Ai::VisionClient, analyze_document: { text: vision_response, usage: nil })
    )
    allow(Ai::Client).to receive(:new).and_return(
      instance_double(Ai::Client, chat: { text: build_categorization_response, usage: nil })
    )
  end

  def setup_orchestrator_mocks
    # Mock VisionExtractor to return success with expected data
    vision_result = ApplicationService::Response.new(
      success: true,
      payload: {
        transactions: [
          {
            "date" => "2025-01-03",
            "description" => "Pago Nomina EMPRESA SA",
            "amount" => 15000.0,
            "transaction_type" => "income"
          }
        ],
        financial_summaries: [],
        opening_balance: 12000.0,
        closing_balance: 13000.0,
        extraction_source: "ai_vision"
      },
      errors: nil
    )
    allow(Statements::VisionExtractor).to receive(:call).and_return(vision_result)

    # Mock PII handler for redaction/restoration
    allow_any_instance_of(Statements::PiiHandler).to receive(:call) do |instance|
      ApplicationService::Response.new(
        success: true,
        payload: instance.instance_variable_get(:@data),
        errors: nil
      )
    end

    allow(Statements::PiiHandler).to receive(:restore) do |_sf, data|
      ApplicationService::Response.new(
        success: true,
        payload: data,
        errors: nil
      )
    end

    # Mock financial summaries creation
    allow(Statements::FinancialSummaryCreator).to receive(:call)
  end

  def setup_importer_mocks
    # Mock Importer to return success without creating real transactions
    allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(
      ApplicationService::Response.new(
        success: true,
        payload: { duplicates_found: false },
        errors: nil
      )
    )

    # Allow StatusManager to run normally - it updates the statement status
  end

  def setup_orchestrator_mocks_for_pii
    # This tests the Text + AI path which properly handles PII restoration
    # Text extraction succeeds, so we use Text + AI path (not Vision)
    allow(TextExtractor).to receive(:valid_text?).and_return(true)

    # Mock Ai::PostProcessor to return data with PII tokens (AI received redacted text)
    ai_result = ApplicationService::Response.new(
      success: true,
      payload: {
        "transactions" => [
          {
            "date" => "2025-08-01",
            "description" => "Payment from ⟪PII:EMAIL:1⟫",
            "amount" => 1200.0,
            "transaction_type" => "income"
          }
        ],
        "financial_summaries" => [],
        "opening_balance" => 0.0,
        "closing_balance" => 1200.0,
        "extraction_source" => "ai_post_processor_text"
      },
      errors: nil
    )
    allow(Ai::PostProcessor).to receive(:call).and_return(ai_result)

    # Mock PII handler for redaction - returns redacted text
    allow(Statements::PiiHandler).to receive(:redact_text) do |_sf, _raw_text|
      { redacted_text: "Payment from ⟪PII:EMAIL:1⟫ on 2025-08-01 amount 1200", map: {} }
    end

    # Mock PII handler for restoration - restores original PII values
    allow(Statements::PiiHandler).to receive(:restore) do |statement_file, data|
      restored_data = data.deep_dup
      transactions = restored_data["transactions"] || restored_data[:transactions]
      if transactions&.any? && statement_file.redaction_map.present?
        transactions.each do |tx|
          statement_file.redaction_map.each do |token, original|
            desc_key = tx.key?("description") ? "description" : :description
            tx[desc_key] = tx[desc_key].gsub(token, original) if tx[desc_key]
          end
        end
      end
      ApplicationService::Response.new(
        success: true,
        payload: restored_data,
        errors: nil
      )
    end

    # Mock financial summaries creation
    allow(Statements::FinancialSummaryCreator).to receive(:call)
  end

  def setup_orchestrator_mocks_for_bbva_credit
    # Mock VisionExtractor to return success with BBVA credit data
    vision_result = ApplicationService::Response.new(
      success: true,
      payload: {
        transactions: [
          {
            "date" => "2025-06-21",
            "description" => "STARBUCKS STORE 05775",
            "amount" => -348.21,
            "transaction_type" => "variable_expense"
          },
          {
            "date" => "2025-06-21",
            "description" => "ROSS STORES N414",
            "amount" => -2323.03,
            "transaction_type" => "variable_expense"
          }
        ],
        financial_summaries: [],
        opening_balance: 54538.87,
        closing_balance: 48351.03,
        extraction_source: "ai_vision"
      },
      errors: nil
    )
    allow(Statements::VisionExtractor).to receive(:call).and_return(vision_result)

    # Mock PII handler
    allow_any_instance_of(Statements::PiiHandler).to receive(:call) do |instance|
      ApplicationService::Response.new(
        success: true,
        payload: instance.instance_variable_get(:@data),
        errors: nil
      )
    end

    allow(Statements::PiiHandler).to receive(:restore) do |_sf, data|
      ApplicationService::Response.new(
        success: true,
        payload: data,
        errors: nil
      )
    end

    # Mock financial summaries creation
    allow(Statements::FinancialSummaryCreator).to receive(:call)
  end

  def setup_text_extraction
    allow(TextExtractor).to receive(:extract_text_layer)
      .and_return("03/01/2025 Pago Nomina EMPRESA SA 15,000.00")
    allow(TextExtractor).to receive(:valid_text?).and_return(true)
  end

  def setup_ai_client
    fake_client = instance_double(Ai::Client)
    allow(Ai::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:chat).and_return(build_ai_response)
  end

  def setup_ai_post_processor(processor)
    success_response = double("Response", success?: true, payload: processor)
    allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(success_response)
  end

  def setup_fallback_parser
    # Don't mock the parsers to return empty transactions - let them fail naturally
    # so the AI fallback is triggered
    allow(PdfParser::Generic).to receive(:call).and_raise("Parser failed")
    allow(PdfParser::BbvaCreditCard).to receive(:call).and_raise("Parser failed")
    allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_raise("Parser failed")
  end

  def build_ai_response
    {
      "opening_balance" => 12000.0,
      "closing_balance" => 13000.0,
      "extraction_source" => "text",
      "transactions" => [
        {
          "date" => "2025-01-03",
          "description" => "Pago Nomina EMPRESA SA",
          "amount" => 15000.0,
          "transaction_type" => "income",
          "merchant" => nil,
          "reference" => nil,
          "category" => "Uncategorized",
          "sub_category" => nil,
          "raw_text" => "03/01/2025 Pago Nomina EMPRESA SA 15,000.00",
          "confidence" => 0.9,
          "category_confidence" => 0.85,
          "transaction_type_confidence" => 0.95
        }
      ]
    }
  end

  def build_ai_response_with_tokens
    {
      "opening_balance" => 0.0,
      "closing_balance" => 0.0,
      "extraction_source" => "text",
      "raw_text" => "Payment from ⟪PII:EMAIL:1⟫ on 2025-08-01 amount 1200",
      "transactions" => [
        {
          "date" => "2025-08-01",
          "description" => "Payment from ⟪PII:EMAIL:1⟫",
          "amount" => 1200.0,
          "transaction_type" => "income"
        }
      ]
    }
  end

  def build_ai_response_with_tokens_vision
    {
      "opening_balance" => 0.0,
      "closing_balance" => 1200.0,
      "financial_summaries" => [],
      "transactions" => [
        {
          "date" => "2025-08-01",
          "description" => "Payment from ⟪PII:EMAIL:1⟫",
          "amount" => 1200.0,
          "transaction_type" => "income"
        }
      ]
    }
  end

  private

  def build_transactions_around_opening_date
    opening_date = Date.new(2025, 1, 15)
    {
      "opening_balance" => 1000.0,
      "closing_balance" => 1200.0,
      "financial_summaries" => [],
      "transactions" => [
        {
          "date" => (opening_date - 5.days).strftime("%Y-%m-%d"),
          "description" => "Historical transaction",
          "amount" => -50.0,
          "transaction_type" => "variable_expense"
        },
        {
          "date" => opening_date.strftime("%Y-%m-%d"),
          "description" => "Transaction on opening balance date",
          "amount" => 100.0,
          "transaction_type" => "income"
        },
        {
          "date" => (opening_date + 5.days).strftime("%Y-%m-%d"),
          "description" => "Future relevant transaction",
          "amount" => 150.0,
          "transaction_type" => "income"
        }
      ]
    }
  end

  def build_vision_json_response
    {
      "transactions" => [
        {
          "date" => "2025-01-03",
          "description" => "Pago Nomina EMPRESA SA",
          "amount" => 15000.0,
          "transaction_type" => "income",
          "merchant" => nil,
          "reference" => nil
        }
      ],
      "financial_summaries" => [],
      "opening_balance" => 12000.0,
      "closing_balance" => 13000.0
    }.to_json
  end

  def build_categorization_response
    {
      "transactions" => [
        {
          "date" => "2025-01-03",
          "description" => "Pago Nomina EMPRESA SA",
          "amount" => 15000.0,
          "transaction_type" => "income",
          "category_id" => nil,
          "sub_category_id" => nil,
          "confidence" => 0.9,
          "category_confidence" => 0.85,
          "transaction_type_confidence" => 0.95
        }
      ]
    }.to_json
  end
end
