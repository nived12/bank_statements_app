# app/models/concerns/text_processing_concern.rb
module TextProcessingConcern
  extend ActiveSupport::Concern

  def chunk_text_for_ai(text, chunk_size: 8000)
    # Simple chunking by character count
    chunks = []

    text.scan(/.{1,#{chunk_size}}/m) do |chunk|
      chunks << chunk
    end

    chunks
  end

  def prepare_text_chunks(text, max_length: 8000)
    if text.length > max_length
      chunk_text_for_ai(text, chunk_size: max_length)
    else
      [ text ]
    end
  end

  def prepare_transaction_text_for_ai(text, bank_account)
    # Extract only transaction-relevant text for AI processing based on bank configuration
    case bank_account.parser_type
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

  private

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
    if transaction_text.length > 4000
      chunk_text_for_ai(transaction_text, chunk_size: 4000)
    else
      [ transaction_text ]
    end
  end
end
