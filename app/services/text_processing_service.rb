# app/services/text_processing_service.rb
class TextProcessingService
  def initialize(statement)
    @statement = statement
  end

  def extract_text(file_path)
    text_layer = TextExtractor.extract_text_layer(file_path)

    if TextExtractor.valid_text?(text_layer)
      @source = "text"
      text_layer
    else
      # Try OCR if text layer extraction fails
      ocr_text = Ocr::Service.extract_text(file_path)

      if TextExtractor.valid_text?(ocr_text)
        @source = "ocr"
        ocr_text
      else
        statement.update(
          status: "error",
          processed_at: Time.current,
          error_message: "No extractable text found after text layer + OCR."
        )
        nil
      end
    end
  end

  def filter_text(text)
    filtered = TransactionTextFilter.filter_for_transactions(text, bank_name: statement.bank_account.bank_name)
    filtered
  end

  def extract_financial_data(text)
    financial_data = TransactionTextFilter.extract_financial_data(text, bank_name: statement.bank_account.bank_name)
    financial_data
  end

  def prepare_text_chunks(text, max_length: nil)
    max_length ||= ConfigurationService.text_chunk_size

    if text.length > max_length
      chunk_text_for_ai(text, chunk_size: max_length)
    else
      [ text ]
    end
  end

  def prepare_transaction_text_for_ai(text)
    # Extract only transaction-relevant text for AI processing based on bank configuration
    case statement.bank_account.parser_type
    when "bbva"
      extract_bbva_transaction_lines(text)
    when "santander", "banorte", "banamex"
      # For these banks, use original logic
      prepare_text_chunks(text)
    else
      # Generic banks use original logic
      prepare_text_chunks(text)
    end
  end

  def source
    @source
  end

  private

  attr_reader :statement

  def chunk_text_for_ai(text, chunk_size: 8000)
    # Simple chunking by character count
    chunks = []

    text.scan(/.{1,#{chunk_size}}/m) do |chunk|
      chunks << chunk
    end

    chunks
  end

  def extract_bbva_transaction_lines(text)
    # Split into lines and keep only lines that look like transactions
    lines = text.split("\n")
    transaction_lines = []

    lines.each do |line|
      line = line.strip
      next if line.empty?

      # Keep lines that look like transactions (have dates and amounts)
      if line.match?(/\d{2}-[a-z]{3}-\d{4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
        transaction_lines << line
      end
    end

    # Join with newlines and limit size
    transaction_text = transaction_lines.join("\n")

    # If still too long, chunk it
    if transaction_text.length > ConfigurationService.transaction_text_chunk_size
      chunk_text_for_ai(transaction_text, chunk_size: ConfigurationService.transaction_text_chunk_size)
    else
      [ transaction_text ]
    end
  end
end
