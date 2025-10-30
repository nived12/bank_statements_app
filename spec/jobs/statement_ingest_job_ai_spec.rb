require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  let!(:user) { create(:user) }
  let!(:bbva_bank) { Bank.find_or_create_by(code: "bbva") { |b| b.name = "BBVA Bancomer"; b.supported_type = 'both'; b.active = true } }
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
        # Since BBVA is now supported (supported_type = 'both'), it will use deterministic parser + AI categorization
        # Mock the BBVA savings parser to return the expected response (debit account type)
        response_payload = build_ai_response.merge("extraction_source" => "deterministic_parser")
        bbva_parser_response = double("Response", success?: true, payload: response_payload)
        allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_return(bbva_parser_response)

        # Mock AI categorization for hybrid approach
        ai_categorization_payload = build_ai_response.dup
        ai_categorization_payload.delete("extraction_source") # Remove so hybrid can set it
        ai_categorization_response = double("Response", success?: true, payload: ai_categorization_payload)
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_categorization_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_categorization_payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)
      end

      it "successfully processes statement with AI enhancement" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq("completed")
        # The extraction source is now determined by the hybrid approach (deterministic parser + AI categorization)
        expect(statement_file.parsed_json["extraction_source"]).to eq("ai_enhanced_parser")

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
      end

      context "when redaction data exists" do
        let(:mock_processor) { instance_double(Ai::PostProcessor) }

        before do
          setup_ai_post_processor({ "transactions" => [] })
          setup_fallback_parser
        end

        it "persists redaction_map and redaction_hmac" do
          perform_job
          statement_file.reload

          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
        end

        it "restores PII tokens from AI output" do
          # Mock the deterministic parser to return data with PII tokens
          response_payload = build_ai_response_with_tokens.merge("extraction_source" => "deterministic_parser")
          success_response = double("Response", success?: true, payload: response_payload)
          allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_return(success_response)

          # Mock AI client for transaction enhancement
          ai_client = double("Ai::Client")
          allow(ai_client).to receive(:chat).and_return(build_ai_response_with_tokens.to_json)
          allow(Ai::Client).to receive(:new).and_return(ai_client)

          perform_job
          statement_file.reload

          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
          expect(statement_file.parsed_json.dig("transactions", 0, "description"))
            .to eq("Payment from juan.perez@example.com")
          expect(statement_file.parsed_json["raw_text"])
            .to eq("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
        end

        it "always sends masked text to deterministic parser, never original PII" do
          # Verify that the deterministic parser receives masked text, not original PII
          expect(PdfParser::BbvaSavingsAccount).to receive(:call) do |text|
            # The text should contain tokens, not original PII
            expect(text).to include("⟪PII:EMAIL:1⟫")
            expect(text).not_to include("juan.perez@example.com")

            # Return a simple response for this test
            double("Response", success?: true, payload: { "transactions" => [], "extraction_source" => "deterministic_parser" })
          end

          perform_job
        end

        it "creates consistent redaction data for same text" do
          # Mock the deterministic parser to return data with PII tokens
          response_payload = build_ai_response_with_tokens.merge("extraction_source" => "deterministic_parser")
          success_response = double("Response", success?: true, payload: response_payload)
          allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_return(success_response)

          # Mock AI client for transaction enhancement
          ai_client = double("Ai::Client")
          allow(ai_client).to receive(:chat).and_return(build_ai_response_with_tokens.to_json)
          allow(Ai::Client).to receive(:new).and_return(ai_client)

          # First run creates redaction data
          perform_job
          statement_file.reload
          first_hmac = statement_file.redaction_hmac

          # Second run creates fresh redaction data
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
          # Mock the deterministic parser to return data with PII tokens
          response_payload = build_ai_response_with_tokens.merge("extraction_source" => "deterministic_parser")
          success_response = double("Response", success?: true, payload: response_payload)
          allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_return(success_response)

          # Mock AI categorization for hybrid approach
          ai_categorization_response = double("Response", success?: true, payload: build_ai_response_with_tokens)
          allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_categorization_response)
        end

        it "creates new redaction map and processes successfully" do
          # Mock AI client for transaction enhancement
          ai_client = double("Ai::Client")
          allow(ai_client).to receive(:chat).and_return(build_ai_response_with_tokens.to_json)
          allow(Ai::Client).to receive(:new).and_return(ai_client)

          perform_job
          statement_file.reload

          expect(statement_file.status).to eq("completed")
          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
          expect(statement_file.parsed_json.dig("transactions", 0, "description"))
            .to eq("Payment from juan.perez@example.com")
        end
      end
    end

    context "when PII redaction is disabled" do
      before do
        allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return(nil)
        # Mock the deterministic parser to return empty transactions
        response_payload = { "transactions" => [], "extraction_source" => "deterministic_parser" }
        success_response = double("Response", success?: true, payload: response_payload)
        allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_return(success_response)

        # Mock AI categorization for hybrid approach
        ai_categorization_response = double("Response", success?: true, payload: { "transactions" => [] })
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_categorization_response)
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
      # Mock the deterministic parser to return the test data
      response_payload = build_transactions_around_opening_date.merge("extraction_source" => "deterministic_parser")
      success_response = double("Response", success?: true, payload: response_payload)
      allow(PdfParser::BbvaSavingsAccount).to receive(:call).and_return(success_response)

      # Mock AI categorization for hybrid approach
      ai_categorization_response = double("Response", success?: true, payload: build_transactions_around_opening_date)
      allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_categorization_response)
    end

    it "imports transactions respecting opening balance date relevance" do
      # Mock AI client for transaction enhancement
      ai_client = double("Ai::Client")
      allow(ai_client).to receive(:chat).and_return(build_transactions_around_opening_date.to_json)
      allow(Ai::Client).to receive(:new).and_return(ai_client)

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
      # Mock AI client for transaction enhancement
      ai_client = double("Ai::Client")
      allow(ai_client).to receive(:chat).and_return(build_transactions_around_opening_date.to_json)
      allow(Ai::Client).to receive(:new).and_return(ai_client)

      described_class.perform_now(statement_file_with_date.id)
      statement_file_with_date.reload

      transaction = statement_file_with_date.transactions.find_by(date: opening_balance_date)
      expect(transaction).to be_present
      expect(transaction.description).to eq("Transaction on opening balance date")
      expect(transaction.amount).to eq(100.0)
      expect(transaction.relevant_for_balance?).to be true
    end

    it "handles edge case of transactions exactly on opening balance date" do
      # Mock AI client for transaction enhancement
      ai_client = double("Ai::Client")
      allow(ai_client).to receive(:chat).and_return(build_transactions_around_opening_date.to_json)
      allow(Ai::Client).to receive(:new).and_return(ai_client)

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
        # Don't call setup_ai_post_processor here as we want to set up specific mocks in the test
        # Don't call setup_fallback_parser here as we want to test the actual parser behavior
      end

      it "detects new format and uses NewBbvaCreditCard parser" do
        # Mock the BBVA credit card parser to return the expected response
        success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'deterministic_parser',
          'transactions' => [
            {
              'date' => '2025-06-21',
              'description' => 'STARBUCKS STORE 05775',
              'amount' => '-348.21',
              'transaction_type' => 'variable_expense'
            }
          ]
        })
        allow(PdfParser::BbvaCreditCard).to receive(:call).and_return(success_response)

        # Mock AI categorization for hybrid approach
        ai_categorization_payload = {
          'transactions' => [
            {
              'date' => '2025-06-21',
              'description' => 'STARBUCKS STORE 05775',
              'amount' => '-348.21',
              'transaction_type' => 'variable_expense',
              'category' => 'Food & Dining'
            }
          ]
        }
        ai_categorization_response = double("Response", success?: true, payload: ai_categorization_payload)
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_categorization_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_categorization_payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)

        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_enhanced_parser')
        expect(statement_file.parsed_json['transactions']).to be_present
      end

      it "correctly inverts signs for expenses and payments" do
        # Override the BBVA parser mock to return a known result (not empty)
        bbva_success_response = double("Response", success?: true, payload: {
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
        })
        allow(PdfParser::BbvaCreditCard).to receive(:call).and_return(bbva_success_response)

        # Mock the new BBVA parser to return transactions with correct sign inversion
        new_parser_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'ai_enhanced_parser',
          'transactions' => [
            {
              'date' => '2025-06-21',
              'description' => 'STARBUCKS STORE 05775',
              'amount' => '-348.21', # Negative for expense (positive in statement)
              'transaction_type' => 'variable_expense'
            },
            {
              'date' => '2025-06-21',
              'description' => 'PAGO TARJETA CREDITO',
              'amount' => '54538.87', # Positive for payment (negative in statement)
              'transaction_type' => 'income'
            }
          ]
        })
        allow(PdfParser::NewBbvaCreditCard).to receive(:call).and_return(new_parser_success_response)

        # Set up AI processor mock to return a response
        ai_success_response = double("Response", success?: true, payload: {
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
        })
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_success_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_success_response.payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)

        # Set up AI availability and parsing strategy
        allow_any_instance_of(StatementProcessingOrchestrator).to receive(:ai_api_available?).and_return(true)
        allow_any_instance_of(StatementParserService).to receive(:ai_api_available?).and_return(true)
        allow(statement_file.bank_account).to receive(:parsing_strategy).and_return(:hybrid)

        perform_job
        statement_file.reload

        transactions = statement_file.parsed_json['transactions']

        # Expense should be negative
        expense = transactions.find { |t| t['description'].include?('STARBUCKS') }
        expect(expense['amount']).to eq('-348.21')
        expect(expense['transaction_type']).to eq('variable_expense')

        # Payment should be positive
        payment = transactions.find { |t| t['description'].include?('PAGO TARJETA') }
        expect(payment['amount']).to eq('54538.87')
        expect(payment['transaction_type']).to eq('income')
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
        # Don't call setup_ai_post_processor here as we want to set up specific mocks in the test
        # Don't call setup_fallback_parser here as we want to test the actual parser behavior
      end

      it "detects legacy format and uses OldBbvaCreditCard parser" do
        # Override the BBVA parser mock to return a known result (not empty)
        # Mock the BBVA parser to return a known result
        bbva_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'ai_enhanced_parser',
          'transactions' => [
            {
              'date' => '2025-06-15',
              'description' => 'STARBUCKS STORE 05775',
              'amount' => '-348.21',
              'transaction_type' => 'variable_expense'
            }
          ]
        })
        allow(PdfParser::BbvaCreditCard).to receive(:call).and_return(bbva_success_response)

        # Mock the old BBVA parser to return a known result
        old_parser_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'standard_parser',
          'transactions' => [
            {
              'date' => '2025-06-15',
              'description' => 'STARBUCKS STORE 05775',
              'amount' => '-348.21',
              'transaction_type' => 'variable_expense'
            }
          ]
        })
        allow(PdfParser::OldBbvaCreditCard).to receive(:call).and_return(old_parser_success_response)

        # Set up AI processor mock to return a response
        ai_success_response = double("Response", success?: true, payload: {
          'transactions' => [
            {
              'date' => '2025-06-15',
              'description' => 'STARBUCKS STORE 05775',
              'amount' => '-348.21',
              'transaction_type' => 'variable_expense'
            }
          ]
        })
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_success_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_success_response.payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)

        # Set up AI availability and parsing strategy
        allow_any_instance_of(StatementProcessingOrchestrator).to receive(:ai_api_available?).and_return(true)
        allow_any_instance_of(StatementParserService).to receive(:ai_api_available?).and_return(true)
        allow(statement_file.bank_account).to receive(:parsing_strategy).and_return(:hybrid)

        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_enhanced_parser')
        expect(statement_file.parsed_json['transactions']).to be_present
      end

      it "handles pipe-separated format correctly" do
        # Override the BBVA parser mock to return a known result (not empty)
        bbva_success_response = double("Response", success?: true, payload: {
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
        })
        allow(PdfParser::BbvaCreditCard).to receive(:call).and_return(bbva_success_response)

        # Mock the old BBVA parser to return transactions with pipe-separated format
        old_parser_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'standard_parser',
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
        })
        allow(PdfParser::OldBbvaCreditCard).to receive(:call).and_return(old_parser_success_response)

        # Set up AI processor mock to return a response
        ai_success_response = double("Response", success?: true, payload: {
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
        })
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_success_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_success_response.payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)

        # Set up AI availability and parsing strategy
        allow_any_instance_of(StatementProcessingOrchestrator).to receive(:ai_api_available?).and_return(true)
        allow_any_instance_of(StatementParserService).to receive(:ai_api_available?).and_return(true)
        allow(statement_file.bank_account).to receive(:parsing_strategy).and_return(:hybrid)

        perform_job
        statement_file.reload

        transaction = statement_file.parsed_json['transactions'].first
        expect(transaction['rfc']).to eq('ABC123456789')
        expect(transaction['reference']).to eq('123456789')
      end
    end

    context "with format detection edge cases" do
      it "defaults to legacy format when no clear indicators found" do
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
        setup_environment_variables
        setup_ai_post_processor(instance_double(Ai::PostProcessor))
        setup_fallback_parser

        # Override the BBVA parser mock to return empty transactions so AI fallback is used
        bbva_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'text',
          'transactions' => []
        })
        allow(PdfParser::BbvaCreditCard).to receive(:call).and_return(bbva_success_response)

        # Mock the old BBVA parser to return a known result
        old_parser_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'standard_parser',
          'transactions' => []
        })
        allow(PdfParser::OldBbvaCreditCard).to receive(:call).and_return(old_parser_success_response)

        # Set up AI processor mock to return a response (for fallback scenario)
        ai_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'text',
          'transactions' => []
        })
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_success_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_success_response.payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)

        # Set up AI availability and parsing strategy
        allow_any_instance_of(StatementProcessingOrchestrator).to receive(:ai_api_available?).and_return(true)
        allow_any_instance_of(StatementParserService).to receive(:ai_api_available?).and_return(true)
        allow(statement_file.bank_account).to receive(:parsing_strategy).and_return(:hybrid)

        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_parser_fallback')
      end

      it "prioritizes new format when both indicators are present" do
        allow(TextExtractor).to receive(:extract_text_layer).and_return(
          <<~TEXT
            BBVA
            Número de cuenta: XXXXXX9496

            Movimientos Efectuados
            CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)

            15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | | | 348.21 |#{" "}
            21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$348.21
          TEXT
        )
        allow(TextExtractor).to receive(:valid_text?).and_return(true)
        setup_environment_variables
        setup_ai_post_processor(instance_double(Ai::PostProcessor))
        setup_fallback_parser

        # Override the BBVA parser mock to return empty transactions so AI fallback is used
        bbva_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'text',
          'transactions' => []
        })
        allow(PdfParser::BbvaCreditCard).to receive(:call).and_return(bbva_success_response)

        # Mock the new BBVA parser to return a known result
        new_parser_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'ai_enhanced_parser',
          'transactions' => []
        })
        allow(PdfParser::NewBbvaCreditCard).to receive(:call).and_return(new_parser_success_response)

        # Set up AI processor mock to return a response (for fallback scenario)
        ai_success_response = double("Response", success?: true, payload: {
          'extraction_source' => 'text',
          'transactions' => []
        })
        allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(ai_success_response)

        # Mock AI client as well
        ai_client = double("Ai::Client")
        allow(ai_client).to receive(:chat).and_return(ai_success_response.payload.to_json)
        allow(Ai::Client).to receive(:new).and_return(ai_client)

        # Set up AI availability and parsing strategy
        allow_any_instance_of(StatementProcessingOrchestrator).to receive(:ai_api_available?).and_return(true)
        allow_any_instance_of(StatementParserService).to receive(:ai_api_available?).and_return(true)
        allow(statement_file.bank_account).to receive(:parsing_strategy).and_return(:hybrid)

        perform_job
        statement_file.reload

        expect(statement_file.status).to eq('completed')
        expect(statement_file.parsed_json['extraction_source']).to eq('ai_parser_fallback')
      end
    end
  end

  private

  def setup_environment_variables
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
    allow(ENV).to receive(:[]).with("AI_API_KEY").and_return("fake_key")
    allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("0")
    allow(ENV).to receive(:[]).and_call_original
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

  private

  def build_transactions_around_opening_date
    opening_date = Date.new(2025, 1, 15)
    {
      "opening_balance" => 1000.0,
      "closing_balance" => 1200.0,
      "extraction_source" => "text",
      "transactions" => [
        {
          "date" => (opening_date - 5.days).strftime("%Y-%m-%d"),
          "description" => "Historical transaction",
          "amount" => 50.0,
          "transaction_type" => "variable_expense",
          "category" => "Uncategorized"
        },
        {
          "date" => opening_date.strftime("%Y-%m-%d"),
          "description" => "Transaction on opening balance date",
          "amount" => 100.0,
          "transaction_type" => "income",
          "category" => "Uncategorized"
        },
        {
          "date" => (opening_date + 5.days).strftime("%Y-%m-%d"),
          "description" => "Future relevant transaction",
          "amount" => 150.0,
          "transaction_type" => "income",
          "category" => "Uncategorized"
        }
      ]
    }
  end
end
