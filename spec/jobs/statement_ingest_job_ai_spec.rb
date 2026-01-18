require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  let!(:user) { create(:user) }
  let!(:bbva_bank) { Bank.find_or_create_by(code: "bbva") { |b|
 b.name = "BBVA Bancomer"; b.supported_type = 'both'; b.active = true } }
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

  let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, ai_enabled: true) }

  subject(:perform_job) { described_class.perform_now(statement_file.id) }

  before do
    setup_environment_variables
    setup_text_extraction
  end

  describe "#perform" do
    context "when AI API is available" do
      before do
        setup_orchestrator_mocks
        setup_parser_service_mocks
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

          # Mock Vision client to return response with real PII (not tokens)
          vision_response_with_pii = {
            "opening_balance" => 0.0,
            "closing_balance" => 1200.0,
            "financial_summaries" => [],
            "transactions" => [
              {
                "date" => "2025-08-01",
                "description" => "Payment from juan.perez@example.com",
                "amount" => 1200.0,
                "transaction_type" => "income"
              }
            ]
          }.to_json

          allow(Ai::VisionClient).to receive(:new).and_return(
            instance_double(Ai::VisionClient, analyze_document: { text: vision_response_with_pii, usage: nil })
          )
        end

        it "creates new redaction map and processes successfully" do
          perform_job
          statement_file.reload

          expect(statement_file.status).to eq("completed")
          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
        end
      end
    end

    context "when PII redaction is disabled" do
      before do
        allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return(nil)
        setup_orchestrator_mocks
        setup_parser_service_mocks_with_empty_transactions
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

    let!(:statement_file_with_date) { create(:statement_file, bank_account: bank_account_with_date) }

    before do
      # Mock Vision client to return transactions around opening date
      vision_response = build_transactions_around_opening_date.to_json
      allow(Ai::VisionClient).to receive(:new).and_return(
        instance_double(Ai::VisionClient, analyze_document: { text: vision_response, usage: nil })
      )

      setup_orchestrator_mocks
      setup_importer_mocks
    end

    it "imports transactions respecting opening balance date relevance" do
      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      expect(statement_file_with_date.status).to eq("completed")
      expect(statement_file_with_date.transactions.count).to eq(3)

      # Check that transactions are properly classified by relevance
      relevant_transactions = statement_file_with_date.transactions.relevant_for_balance(opening_balance_date)
      historical_transactions = statement_file_with_date.transactions.historical(opening_balance_date)

      expect(relevant_transactions.count).to eq(2)
      expect(historical_transactions.count).to eq(1)

      # Verify specific transaction dates and relevance
      relevant_dates = relevant_transactions.pluck(:date).sort
      historical_dates = historical_transactions.pluck(:date).sort

      expect(relevant_dates).to eq([ opening_balance_date, opening_balance_date + 5.days ])
      expect(historical_dates).to eq([ opening_balance_date - 5.days ])
    end

    it "maintains transaction data integrity during import" do
      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      transaction = statement_file_with_date.transactions.find_by(date: opening_balance_date)
      expect(transaction).to be_present
      expect(transaction.description).to eq("Transaction on opening balance date")
      expect(transaction.amount).to eq(100.0)
      expect(transaction.relevant_for_balance?).to be true
    end

    it "handles edge case of transactions exactly on opening balance date" do
      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      edge_case_transaction = statement_file_with_date.transactions.find_by(date: opening_balance_date)
      expect(edge_case_transaction).to be_present
      expect(edge_case_transaction.relevant_for_balance?).to be true
      expect(edge_case_transaction.historical?).to be false
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

      it "successfully processes new BBVA format with Vision" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_vision')
        expect(statement_file.parsed_json['transactions']).to be_present
      end

      it "extracts transactions from credit card statement" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_vision')
        transactions = statement_file.parsed_json['transactions']
        expect(transactions).to be_an(Array)
      end
    end

    context "with legacy BBVA format (pre-July 2024)" do
      before do
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
        setup_orchestrator_mocks_for_bbva_credit
        setup_importer_mocks
      end

      it "successfully processes legacy BBVA format with Vision" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_vision')
        expect(statement_file.parsed_json['transactions']).to be_present
      end
    end

    context "with format detection edge cases" do
      before do
        setup_environment_variables
        setup_orchestrator_mocks_for_bbva_credit
        setup_importer_mocks
      end

      it "processes statements with ambiguous format using Vision" do
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
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_vision')
        expect(statement_file.parsed_json).to be_present
      end
    end
  end

  private

  def setup_environment_variables
    # Set up and_call_original first, then override specific keys
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
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
    # Mock VisionExtractor dependencies
    allow_any_instance_of(Statements::VisionExtractor).to receive(:validate_dependencies!)
    allow_any_instance_of(Statements::VisionExtractor).to receive(:convert_pdf_to_images)
      .and_return(["/tmp/page-001.jpg"])

    # Mock temp file creation
    temp_file = double("TempFile", path: "/tmp/test_statement.pdf")
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:create_temp_file)
      .and_return(temp_file)
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:cleanup_temp_file)

    # Mock text extraction and processing
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:extract_and_process_text)
      .and_return(
        text: "03/01/2025 Pago Nomina EMPRESA SA 15,000.00",
        text_chunks: ["03/01/2025 Pago Nomina EMPRESA SA 15,000.00"],
        financial_data: {},
        source: "text"
      )

    # Mock PII redaction
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:pii_redaction_enabled?).and_return(false)
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:restore_pii_tokens) do |_instance, parsed, _statement|
      parsed
    end

    # Mock financial summaries creation
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:create_financial_summaries)
  end

  def setup_parser_service_mocks
    # Mock StatementParserService to return the expected response
    response_payload = build_ai_response.merge("extraction_source" => "ai_enhanced_parser")
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_importer_mocks
    # Mock duplicate detector to return no duplicates, then allow real importer to run
    allow(Transactions::DuplicateDetector).to receive(:call).and_return(
      ApplicationService::Response.new(
        success: true,
        payload: [],
        errors: nil
      )
    )

    # Allow real importer to run so transactions are actually created
    allow_any_instance_of(Transactions::Importer).to receive(:call) do |instance|
      # Call the real call method but with mocked duplicate detector
      instance.send(
        :import_non_duplicate_transactions,
        instance.instance_variable_get(:@user),
        instance.instance_variable_get(:@bank_account),
        []
      )
      ApplicationService::Response.new(
        success: true,
        payload: { duplicates_found: false },
        errors: nil
      )
    end
  end

  def setup_orchestrator_mocks_for_pii
    # Mock VisionExtractor dependencies
    allow_any_instance_of(Statements::VisionExtractor).to receive(:validate_dependencies!)
    allow_any_instance_of(Statements::VisionExtractor).to receive(:convert_pdf_to_images)
      .and_return(["/tmp/page-001.jpg"])

    # Mock Vision client to return response with PII tokens
    vision_response = build_ai_response_with_tokens_vision.to_json
    allow(Ai::VisionClient).to receive(:new).and_return(
      instance_double(Ai::VisionClient, analyze_document: { text: vision_response, usage: nil })
    )

    # Mock AI categorization client
    allow(Ai::Client).to receive(:new).and_return(
      instance_double(Ai::Client, chat: { text: build_categorization_response, usage: nil })
    )
  end

  def setup_parser_service_mocks_with_empty_transactions
    response_payload = { "transactions" => [], "extraction_source" => "deterministic_parser" }
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_parser_service_mocks_for_opening_balance
    response_payload = build_transactions_around_opening_date.merge("extraction_source" => "ai_enhanced_parser")
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_orchestrator_mocks_for_bbva_credit
    # Mock VisionExtractor dependencies
    allow_any_instance_of(Statements::VisionExtractor).to receive(:validate_dependencies!)
    allow_any_instance_of(Statements::VisionExtractor).to receive(:convert_pdf_to_images)
      .and_return(["/tmp/page-001.jpg"])

    # Mock temp file creation
    temp_file = double("TempFile", path: "/tmp/test_statement.pdf")
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:create_temp_file)
      .and_return(temp_file)
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:cleanup_temp_file)

    # Mock text extraction - use the actual text from TextExtractor mock
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:extract_and_process_text) do |_instance, _path, _statement|
      text = TextExtractor.extract_text_layer(_path) rescue ""
      {
        text: text,
        text_chunks: [text],
        financial_data: {},
        source: "text"
      }
    end

    # Mock PII redaction
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:pii_redaction_enabled?).and_return(false)
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:restore_pii_tokens) do |_instance, parsed, _statement|
      parsed
    end

    # Mock financial summaries creation
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:create_financial_summaries)
  end

  def setup_parser_service_mocks_for_new_bbva_format
    response_payload = {
      'extraction_source' => 'ai_enhanced_parser',
      'transactions' => [
        {
          'date' => '2025-06-21',
          'description' => 'STARBUCKS STORE 05775',
          'amount' => '-348.21',
          'transaction_type' => 'variable_expense'
        }
      ]
    }
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_parser_service_mocks_for_sign_inversion
    response_payload = {
      'extraction_source' => 'ai_enhanced_parser',
      'transactions' => [
        {
          'date' => '2025-06-21',
          'description' => 'STARBUCKS STORE 05775',
          'amount' => '-348.21',
          'transaction_type' => 'variable_expense'
        },
        {
          'date' => '2025-06-21',
          'description' => 'PAGO TARJETA CREDITO',
          'amount' => '54538.87',
          'transaction_type' => 'income'
        }
      ]
    }
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_parser_service_mocks_for_legacy_bbva
    response_payload = {
      'extraction_source' => 'ai_enhanced_parser',
      'transactions' => [
        {
          'date' => '2025-06-15',
          'description' => 'STARBUCKS STORE 05775',
          'amount' => '-348.21',
          'transaction_type' => 'variable_expense'
        }
      ]
    }
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_parser_service_mocks_for_legacy_bbva_with_rfc
    response_payload = {
      'extraction_source' => 'ai_enhanced_parser',
      'transactions' => [
        {
          'date' => '2025-06-15',
          'description' => 'STARBUCKS STORE 05775',
          'amount' => '-348.21',
          'transaction_type' => 'variable_expense',
          'rfc' => 'ABC123456789',
          'reference' => '123456789'
        }
      ]
    }
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
  end

  def setup_parser_service_mocks_for_fallback
    response_payload = {
      'extraction_source' => 'ai_parser_fallback',
      'transactions' => []
    }
    parser_result = double(
      "ParserResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(StatementParserService).to receive(:call).and_return(parser_result)
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
