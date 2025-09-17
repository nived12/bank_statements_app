# frozen_string_literal: true

##
# TextProcessable
# Comprehensive concern module for all text processing operations including extraction, OCR, PII redaction, chunking, filtering, and financial data extraction
#
# Usage:
# include TextProcessable in your service class and you can use:
#   text_data = extract_and_process_text(file_path, statement)
#   chunks = prepare_text_chunks(text, max_length: 8000)
#   financial_data = extract_financial_data(text, bank_name)
#   filtered_text = filter_for_transactions(text, bank_name)
#
module TextProcessable
  private

  def extract_and_process_text(file_path, statement)
    # Consolidated text extraction and processing
    text_layer = TextExtractor.extract_text_layer(file_path)
    source = "text"

    unless TextExtractor.valid_text?(text_layer)
      # Try OCR if text layer extraction fails
      ocr_result = OcrService.call(file_path)

      if ocr_result.success? && TextExtractor.valid_text?(ocr_result.payload)
        text_layer = ocr_result.payload
        source = "ocr"
      else
        statement.update(
          status: "error",
          processed_at: Time.current,
          error_message: "No extractable text found after text layer + OCR."
        )
        return
      end
    end

    # Apply PII redaction if the including class supports it
    if respond_to?(:apply_pii_redaction)
      text_layer = apply_pii_redaction(text_layer, statement)
    end

    # Extract financial data and prepare text chunks
    financial_data = extract_financial_data(text_layer, bank_name: statement.bank_account.bank_name)
    text_chunks = prepare_text_chunks(text_layer)

    {
      text: text_layer,
      text_chunks: text_chunks,
      financial_data: financial_data,
      source: source
    }
  rescue => e
    # Log error if the including class supports it
    if respond_to?(:log_error)
      log_error(e, context: "PII redaction", data: { statement_id: statement.id })
    end
    raise
  end

  def prepare_text_chunks(text, max_length: nil)
    # Use text_chunk_size if available, otherwise default to 15000
    max_length ||= (respond_to?(:text_chunk_size) ? text_chunk_size : 15000)

    if text.length > max_length
      # Use smart chunking that preserves transaction integrity
      smart_chunk_result = chunk_by_transaction_count(text)
      if smart_chunk_result.success?
        smart_chunk_result.payload
      else
        # Fallback to simple chunking if smart chunking fails
        chunk_text_for_ai(text, chunk_size: max_length)
      end
    else
      [ text ]
    end
  end

  def chunk_text_for_ai(text, chunk_size: 8000)
    chunks = []
    text.scan(/.{1,#{chunk_size}}/m) do |chunk|
      chunks << chunk
    end
    chunks
  end

  # Financial data extraction
  def extract_financial_data(text, bank_name: nil)
    bank_type = detect_bank_type(bank_name)
    extractor = FinancialDataExtractor.new(bank_type)
    extractor.extract_financial_data(text)
  end

  def detect_bank_type(bank_name)
    return "generic" if bank_name.blank?

    bank_name.to_s.downcase
  end

  def chunk_by_transaction_count(text)
    unless text.is_a?(String)
      errors.add(:base, "Input must be a String")
      return failure
    end

    # Smart chunking based on transaction count - optimize for AI processing
    lines = text.split("\n")
    chunks = []
    current_chunk = []
    transaction_count = 0

    lines.each do |line|
      line = line.strip
      next if line.empty?

      # Check if this line looks like a transaction
      if transaction_line?(line)
        transaction_count += 1
      end

      current_chunk << line

      # Create a new chunk every configured number of transactions to balance cost vs accuracy
      batch_size = respond_to?(:ai_batch_size) ? ai_batch_size : 50
      if transaction_count >= batch_size
        chunks << current_chunk.join("\n")
        current_chunk = []
        transaction_count = 0
      end
    end

    # Add the last chunk if it has content
    chunks << current_chunk.join("\n") if current_chunk.any?

    success(chunks)
  rescue => e
    errors.add(:base, "Failed to chunk text by transaction count: #{e.message}")
    failure
  end

  def transaction_line?(line)
    return false unless line.is_a?(String)

    # More inclusive heuristics to identify transaction lines
    # Date patterns (various formats)
    line.match?(/\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}/) || # DD-MM-YYYY, DD/MM/YYYY, etc.
    line.match?(/\d{1,2}-[a-z]{3}-\d{4}/i) || # DD-MMM-YYYY
    line.match?(/\d{1,2}\/\w{3}\/\d{4}/i) || # DD/MMM/YYYY
    line.match?(/\d{1,2}\/\d{1,2}\/\d{4}/) || # DD/MM/YYYY

    # Amount patterns (various formats) - be more specific to avoid false positives
    line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/) || # +$1,234.56 or -567.89
    line.match?(/\$\s*[\d,]+\.\d{2}(?:\s|$)/) || # $1,234.56 (with word boundary)
    # Only match standalone amounts if they're not part of summary text
    (line.match?(/\b[\d,]+\.\d{2}\b/) && !line.match?(/(?:total|balance|summary|period|statement|account|header|information)/i)) ||

    # Banking keywords (expanded list)
    line.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC|ABONO|CARGO|COMPRA|VENTA|TRANSFERENCIA|MOVIMIENTO)/i) ||

    # Company/merchant patterns (general patterns, not specific names)
    line.match?(/\b[A-Z]{2,}\s+[A-Z0-9\s]+\b/) || # ALL CAPS company names
    line.match?(/\b[A-Z]+\*[A-Z\s]+\b/) || # TST*THE WINDOW pattern
    line.match?(/\b[A-Z]+\.[A-Z]+\b/) || # BMOVIL.PAGO pattern
    line.match?(/\b[A-Z]{3,}\s+[A-Z]{3,}\b/) || # Multi-word company names

    # Reference numbers and codes
    line.match?(/\b\d{6,}\b/) ||

    # General merchant indicators (not specific names)
    line.match?(/\b(SUPER|STORE|MARKET|SHOP|RESTAURANT|HOTEL|GAS|STATION|CENTER|MALL|PLAZA)\b/i) || # Common business types
    line.match?(/\b[A-Z]{2,}\d{2,}\b/) || # Alphanumeric codes (like store numbers)
    line.match?(/\b[A-Z]{3,}\s+\d{2,}\b/) # Company name with numbers
  end
end
