# app/services/statements/vision_extractor.rb
require "open3"
require "timeout"

module Statements
  class VisionExtractor < ApplicationService
    include FileHandling
    include ErrorHandling

    # System dependencies required for this service
    class DependencyError < StandardError; end

    IMAGE_DPI = 150
    IMAGE_QUALITY = 90
    MAX_PAGES = 50 # Safety limit
    CONVERSION_TIMEOUT = 60 # seconds

    def initialize(statement_file)
      super()
      @statement_file = statement_file
      @bank_name = statement_file.bank_account&.bank&.name || "Unknown Bank"
      @account_type = statement_file.bank_account&.account_type || "unknown"
      @temp_files = []
    end

    def call
      # Validate all prerequisites upfront
      validate_dependencies!
      validate_statement_file!

      # Download PDF from ActiveStorage
      pdf_path = download_pdf_from_active_storage

      # Convert PDF to images using ImageMagick + Ghostscript
      images = convert_pdf_to_images(pdf_path)
      return failure("PDF conversion failed - no images generated") if images.empty?

      # Build bank-specific extraction prompt
      prompt = build_vision_prompt

      # Call Gemini Vision API
      response_with_metadata = call_vision_api(images, prompt)
      return failure("Vision API returned empty response") if response_with_metadata[:text].blank?

      # Store usage metadata and calculate costs
      if response_with_metadata[:usage].present?
        log_extraction_cost(response_with_metadata[:usage])
      end

      # Parse and validate JSON response
      parsed_data = parse_vision_response(response_with_metadata[:text])
      return failure("Failed to parse Vision API response") unless parsed_data

      success(
        {
          transactions: parsed_data["transactions"] || [],
          financial_summaries: parsed_data["financial_summaries"] || [],
          opening_balance: parsed_data["opening_balance"],
          closing_balance: parsed_data["closing_balance"],
          extraction_source: "ai_vision"
        }
      )
    rescue Ai::VisionClient::ApiError => e
      log_error(e, context: "Vision API error", data: context_for_logging)
      failure("Vision API error: #{e.message}")
    rescue DependencyError => e
      log_error(e, context: "Missing dependency", data: context_for_logging)
      failure(e.message)
    rescue StandardError => e
      log_error(e, context: "Vision extraction failed", data: context_for_logging)
      failure("Extraction failed: #{e.message}")
    ensure
      cleanup_temp_files
    end

    private

    attr_reader :statement_file, :bank_name, :account_type, :temp_files

    # Validate system dependencies before processing
    def validate_dependencies!
      # Check ImageMagick
      magick_path = `which magick 2>/dev/null`.strip
      if magick_path.empty?
        raise DependencyError, "ImageMagick not installed. Install with: brew install imagemagick"
      end

      # Check Ghostscript (required by ImageMagick for PDF conversion)
      gs_path = `which gs 2>/dev/null`.strip
      if gs_path.empty?
        raise DependencyError, "Ghostscript not installed. Install with: brew install ghostscript"
      end

      Rails.logger.debug("Dependencies validated: ImageMagick=#{magick_path}, Ghostscript=#{gs_path}")
    end

    def validate_statement_file!
      unless statement_file.file.attached?
        raise ArgumentError, "Statement file has no attached PDF"
      end
    end

    # Download PDF from ActiveStorage with proper binary handling
    def download_pdf_from_active_storage
      temp_file = Tempfile.new(["statement", ".pdf"], binmode: true)
      @temp_files << temp_file

      # Use ActiveStorage's open method for proper binary handling
      statement_file.file.open do |file|
        IO.copy_stream(file, temp_file)
      end

      temp_file.flush
      temp_file.close
      temp_file.path
    end

    # Convert PDF to images using ImageMagick (requires Ghostscript)
    def convert_pdf_to_images(pdf_path)
      output_dir = Dir.mktmpdir
      @temp_files << output_dir
      output_pattern = File.join(output_dir, "page-%03d.jpg")

      command = [
        "magick",
        "-density", IMAGE_DPI.to_s,
        pdf_path,
        "-quality", IMAGE_QUALITY.to_s,
        "-background", "white",
        "-alpha", "remove",
        "-colorspace", "sRGB",  # Ensure consistent color space
        output_pattern
      ]

      Rails.logger.info("Converting PDF to images (DPI: #{IMAGE_DPI}, Quality: #{IMAGE_QUALITY})")
      Rails.logger.debug("Command: #{command.join(" ")}")

      _stdout, stderr, status = nil
      begin
        Timeout.timeout(CONVERSION_TIMEOUT) do
          _stdout, stderr, status = Open3.capture3(*command)
        end
      rescue Timeout::Error
        Rails.logger.error("ImageMagick conversion timed out after #{CONVERSION_TIMEOUT}s")
        return []
      end

      unless status&.success?
        # Parse stderr for helpful error messages
        error_msg = parse_imagemagick_error(stderr)
        Rails.logger.error("ImageMagick conversion failed: #{error_msg}")
        Rails.logger.debug("Full stderr: #{stderr}")
        return []
      end

      images = Dir.glob(File.join(output_dir, "page-*.jpg")).sort

      if images.empty?
        Rails.logger.error("No images generated from PDF")
        return []
      end

      if images.count > MAX_PAGES
        Rails.logger.warn("PDF has #{images.count} pages, limiting to #{MAX_PAGES}")
        images = images.first(MAX_PAGES)
      end

      Rails.logger.info("Successfully generated #{images.count} images from PDF")
      images
    rescue StandardError => e
      log_error(e, context: "PDF to image conversion", data: context_for_logging)
      []
    end

    # Parse ImageMagick error messages to provide helpful guidance
    def parse_imagemagick_error(stderr)
      case stderr
      when /gs: command not found/
        "Ghostscript not found. Install with: brew install ghostscript"
      when /FailedToExecuteCommand.*gs/
        "Ghostscript execution failed. Ensure Ghostscript is properly installed."
      when /unauthorized/
        "PDF processing unauthorized. Check ImageMagick policy.xml configuration."
      else
        stderr.lines.first(3).join(" ").strip
      end
    end

    def build_vision_prompt
      categories_json = build_categories_json

      <<~PROMPT
        You are analyzing a bank statement from #{bank_name} (#{account_type} account).

        Your task is to extract ALL transactions, categorize them, and extract financial summary information.

        TRANSACTION EXTRACTION:
        Look for the MAIN transaction table (usually the largest table in the statement).
        Common column headers:
        - Date: FECHA, DATE, Fecha operación, Fecha de cargo
        - Description: DESCRIPCIÓN, CONCEPTO, Descripción, Detalle
        - Amount: MONTO, CARGO, ABONO, IMPORTE, Monto, Amount
        - Reference: REFERENCIA, REF, No. Autorización

        Extract ALL transactions from the main table, EXCEPT:
        1. If the FIRST row's description is "Saldo Anterior" or "Previous Balance" → skip it (this is the opening balance, not a transaction)
        2. Transactions with descriptions matching pattern "## DE ##" (e.g., "02 DE 03", "1 DE 12")
           → These are installment payment line items, not actual transaction charges
        3. Installment summary tables: Skip tables labeled "DIFERIDOS" or "A MESES" - these show payment schedules, not new transactions
        4. If you see duplicate transactions (same date, description, amount) in both:
           - Main transaction table AND
           - A separate summary table
           → Only include it ONCE (from the main table)

        For each transaction extract:
        - date: Format as YYYY-MM-DD
        - description: Full transaction description (keep as-is, including words like "A MESES" or "DIFERIDO")
        - amount: Numeric value (positive for deposits/credits, negative for charges/debits)
        - reference: Any reference number or authorization code (optional)

        TRANSACTION CATEGORIZATION:
        For each transaction, also determine:
        - merchant: Clean merchant name extracted from the description (e.g., "UBER EATS" from "UBER EATS*ORDER123")
        - transaction_type: One of "expense", "income", or "transfer"
        #{categories_json.present? ? "- category_id: Match to the most appropriate category from this list: #{categories_json}" : ""}

        FINANCIAL SUMMARY EXTRACTION:
        Look for summary sections with:
        - Opening balance (Saldo anterior, Saldo inicial, Previous balance)
        - Closing balance (Saldo final, Saldo actual, Current balance, Nuevo saldo)
        - Total deposits/credits (Total abonos, Depósitos, Pagos - for credit cards)
        - Total charges/debits (Total cargos, Retiros, Compras - for credit cards)

        IMPORTANT RULES:
        1. Extract ONLY current billing period transactions - skip installment summary tables
        2. For credit cards: purchases are negative, payments are positive
        3. For debit/savings: deposits are positive, withdrawals are negative
        4. Include the reference number if visible
        5. Keep descriptions exactly as shown (don't summarize)
        6. Return ONLY valid JSON (no markdown, no explanations)

        Return JSON in this EXACT format:
        {
          "transactions": [
            {
              "date": "YYYY-MM-DD",
              "description": "Transaction description",
              "amount": -123.45,
              "reference": "REF123",
              "merchant": "Merchant Name",
              "transaction_type": "expense",
              "category_id": 1
            }
          ],
          "financial_summaries": [
            {
              "start_date": "YYYY-MM-DD",
              "end_date": "YYYY-MM-DD",
              "total_deposits": 1000.00,
              "total_withdrawals": 500.00
            }
          ],
          "opening_balance": 1000.00,
          "closing_balance": 1500.00
        }
      PROMPT
    end

    def build_categories_json
      user = statement_file.user
      return unless user&.categories&.any?

      categories = user.categories.map { |c| { id: c.id, name: c.name } }
      categories.to_json
    end

    def call_vision_api(images, prompt)
      vision_client = Ai::VisionClient.new
      vision_client.analyze_document(images, prompt)
    end

    def parse_vision_response(response)
      cleaned = clean_response(response)
      JSON.parse(cleaned)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Vision API JSON response: #{e.message}")
      Rails.logger.error("Response preview: #{cleaned[0..500]}")
      nil
    end

    def clean_response(response)
      cleaned = response.strip

      # Remove markdown code blocks
      cleaned = cleaned.gsub(/^```json\s*/m, "")
      cleaned = cleaned.gsub(/^```\s*/m, "")
      cleaned = cleaned.gsub(/\s*```$/m, "")

      cleaned.strip
    end

    def cleanup_temp_files
      @temp_files.each do |file_or_dir|
        next unless file_or_dir

        if file_or_dir.is_a?(String) && Dir.exist?(file_or_dir)
          FileUtils.rm_rf(file_or_dir)
        elsif file_or_dir.respond_to?(:close) && file_or_dir.respond_to?(:unlink)
          file_or_dir.close unless file_or_dir.closed?
          file_or_dir.unlink
        end
      rescue StandardError => e
        Rails.logger.warn("Failed to cleanup temp file: #{e.message}")
      end
    end

    def context_for_logging
      {
        statement_file_id: statement_file.id,
        bank_name: bank_name,
        account_type: account_type,
        user_id: statement_file.user_id
      }
    end

    def log_extraction_cost(usage)
      return unless usage.present?

      # Gemini 3 Flash Preview pricing
      input_tokens = usage[:prompt_token_count] || 0
      output_tokens = usage[:candidates_token_count] || 0
      total_tokens = usage[:total_token_count] || (input_tokens + output_tokens)

      input_cost_usd = (input_tokens / 1_000_000.0) * Ai::Concerns::Pricing::Gemini::FLASH_PREVIEW_INPUT_COST
      output_cost_usd = (output_tokens / 1_000_000.0) * Ai::Concerns::Pricing::Gemini::FLASH_PREVIEW_OUTPUT_COST
      total_cost_usd = input_cost_usd + output_cost_usd
      total_cost_mxn = total_cost_usd * Ai::Concerns::Pricing::USD_TO_MXN_RATE

      Rails.logger.info(
        "Vision extraction cost: $#{total_cost_usd.round(4)} USD / $#{total_cost_mxn.round(2)} MXN " \
        "(#{input_tokens} input + #{output_tokens} output = #{total_tokens} total tokens)"
      )

      # Store in usage_metadata with extraction-specific keys
      current_metadata = @statement_file.usage_metadata || {}
      @statement_file.update(
        usage_metadata: current_metadata.merge(
          "extraction" => {
            "prompt_token_count" => input_tokens,
            "candidates_token_count" => output_tokens,
            "total_token_count" => total_tokens,
            "cost_usd" => total_cost_usd.round(6),
            "cost_mxn" => total_cost_mxn.round(2)
          }
        )
      )
    end
  end
end
