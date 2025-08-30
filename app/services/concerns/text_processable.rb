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
        return nil
      end
    end

    # Apply PII redaction if enabled
    if pii_redaction_enabled?
      redacted_text, map, hmac = PiiRedactor.new.redact_preserving_transactions(text_layer)

      if map.present?
        statement.update!(redaction_map: map, redaction_hmac: hmac)
      else
        statement.update!(redaction_map: {}, redaction_hmac: hmac)
      end

      text_layer = redacted_text
    end

    # Extract financial data and prepare text chunks
    financial_data = extract_financial_data(text_layer, bank_name: statement.bank_account.bank_name)
    filtered_text = filter_for_transactions(text_layer, bank_name: statement.bank_account.bank_name)
    text_chunks = prepare_text_chunks(filtered_text)

    {
      text: text_layer,
      filtered_text: filtered_text,
      text_chunks: text_chunks,
      financial_data: financial_data,
      source: source
    }
  rescue => e
    if pii_redaction_enabled?
      handle_pii_error(statement, e)
    end
    raise
  end

  def prepare_text_chunks(text, max_length: nil)
    max_length ||= text_chunk_size

    if text.length > max_length
      chunk_text_for_ai(text, chunk_size: max_length)
    else
      [text]
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

  # Text filtering for transactions
  def filter_for_transactions(text, bank_name: nil)
    # Clean corrupted text first
    text = clean_corrupted_text(text)
    bank_type = detect_bank_type(bank_name)
    patterns = get_patterns_for_bank(bank_type)

    # Split text into lines and filter
    lines = split_text_into_lines(text)
    filtered_lines = filter_lines(lines, patterns, bank_type)

    # Join lines back together
    filtered_lines.join("\n")
  end

  # Text processing utilities
  def split_text_into_lines(text)
    if text.include?("\n")
      text.split("\n")
    else
      # For PDF text without line breaks, reconstruct lines
      reconstruct_lines_from_pdf_text(text)
    end
  end

  def filter_lines(lines, patterns, bank_type)
    lines.each_with_object([]) do |line, filtered_lines|
      line = line.strip
      next if line.empty?

      # Always filter out balance lines
      next if line.match?(/^Saldo (Promedio|Final):\s*[\d,]+\.\d{2}$/i)

      if should_keep_line?(line, patterns, bank_type)
        filtered_lines << line
      elsif is_transaction_continuation?(line, filtered_lines, bank_type)
        filtered_lines << line
      end
    end
  end

  def reconstruct_lines_from_pdf_text(text)
    lines = []
    current_line = ""

    # Split on multiple spaces to get potential line breaks
    parts = text.split(/\s{3,}/)

    parts.each do |part|
      part = part.strip
      next if part.empty?

      # If this part looks like it could be the start of a new transaction line
      if part.match?(/\d{2}-[a-z]{3}-\d{4}/) || part.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
        # Save the previous line if it exists
        lines << current_line.strip if current_line.strip.length > 0
        current_line = part
      else
        # This is a continuation of the current line
        current_line += " " + part
      end
    end

    # Add the last line
    lines << current_line.strip if current_line.strip.length > 0
    lines
  end

  def clean_corrupted_text(text)
    return text unless text.is_a?(String)

    # Remove invalid ASCII control characters (0-31, except 9, 10, 13)
    text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

    # Remove other problematic characters that might cause AI parsing issues
    text = text.gsub(/[▯]/, "")  # Remove placeholder characters
    text = text.gsub(/[\uFFFD]/, "")  # Remove replacement characters
    text = text.gsub(/[\u0000-\u001F\u007F-\u009F]/, "")  # Remove other control characters

    # Normalize whitespace
    text = text.gsub(/\s+/, " ")
    text = text.gsub(/\n\s*\n/, "\n")  # Remove empty lines

    text
  end

  def detect_bank_type(bank_name)
    return "generic" if bank_name.blank?

    bank_name.to_s.downcase
  end
end
