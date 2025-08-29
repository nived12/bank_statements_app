# app/services/ai/text_processor.rb
module Ai
  class TextProcessor < ApplicationService
    def initialize
      super()
    end

    def parsed_transactions?(raw_text)
      unless raw_text.is_a?(String)
        errors.add(:base, "Input must be a String")
        return failure
      end

      # Check if the input looks like already parsed transactions
      # vs raw statement text that needs parsing
      lines = raw_text.split("\n")

      # Look for transaction-like patterns in descriptions
      transaction_lines = lines.count do |line|
        line = line.strip
        next false if line.empty?

        # Check for common transaction keywords
        line.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)/i) ||
        # Check for reference numbers and codes
        line.match?(/\b\d{6,}\b/) ||
        # Check for company names
        line.match?(/\b(BITSO|OXXO|HSBC|BBVA|APPTEGY|INFONAVIT|APIC|MBAN|PORTABILIDAD)\b/i)
      end

      # If more than 60% of lines look like transaction descriptions, this is likely parsed data
      result = transaction_lines.to_f / lines.length > 0.6
      success(result)
    rescue => e
      errors.add(:base, "Failed to detect parsed transactions: #{e.message}")
      failure
    end

    def extract_keywords_inline(text)
      unless text.is_a?(String)
        errors.add(:base, "Input must be a String")
        return failure
      end

      # INLINE METHOD: Process text directly without calling external method
      lines = text.split("\n")
      result_lines = []

      lines.each do |line|
        line = line.strip
        next if line.empty?

        words = line.split(/\s+/)
        # Take first 3-4 words for categorization
        result_lines << words.first(4).join(" ")
      end

      result = result_lines.join("\n")
      success(result)
    rescue => e
      errors.add(:base, "Failed to extract keywords inline: #{e.message}")
      failure
    end

    def shorten_transaction_descriptions(text)
      unless text.is_a?(String)
        errors.add(:base, "Input must be a String")
        return failure
      end

      # Split into lines and shorten each transaction description
      lines = text.split("\n")
      shortened_lines = lines.map do |line|
        line = line.strip
        next line if line.empty?

        # Extract key words for categorization
        words = line.split(/\s+/)
        key_words = words.select do |word|
          # Keep important words for categorization
          word.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)$/i) ||
          word.match?(/^(BITSO|OXXO|HSBC|BBVA|APPTEGY|INFONAVIT|APIC|MBAN|PORTABILIDAD)$/i) ||
          word.length <= 8  # Keep short words
        end

        # Limit to first 10 key words to avoid token limits
        key_words.first(10).join(" ")
      end

      result = shortened_lines.join("\n")
      success(result)
    rescue => e
      errors.add(:base, "Failed to shorten transaction descriptions: #{e.message}")
      failure
    end

    def extract_essential_transaction_keywords(text)
      unless text.is_a?(String)
        errors.add(:base, "Input must be a String")
        return failure
      end

      # Extract only essential keywords for categorization - cost effective approach
      lines = text.split("\n")
      essential_lines = []

      lines.each do |line|
        line = line.strip
        next if line.empty?

        # Extract only the most important words for categorization
        words = line.split(/\s+/)
        essential_words = words.select do |word|
          # Keep only the most important categorization keywords
          word.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)$/i) ||
          word.match?(/^(BITSO|OXXO|HSBC|BBVA|APPTEGY|INFONAVIT|APIC|MBAN|PORTABILIDAD)$/i)
        end

        # Always add a line, even if no keywords found (use first few words)
        if essential_words.any?
          essential_lines << essential_words.first(5).join(" ")
        else
          essential_lines << words.first(3).join(" ")
        end
      end

      # Keep lines separate for better AI processing
      result = essential_lines.join("\n")
      success(result)
    rescue => e
      errors.add(:base, "Failed to extract essential keywords: #{e.message}")
      failure
    end

    def extract_keywords_simple(text)
      unless text.is_a?(String)
        errors.add(:base, "Input must be a String")
        return failure
      end

      # SIMPLE METHOD: Just split and take first few words per line
      lines = text.split("\n")
      result_lines = []

      lines.each do |line|
        line = line.strip
        next if line.empty?

        words = line.split(/\s+/)
        # Take first 3-4 words for categorization
        result_lines << words.first(4).join(" ")
      end

      result = result_lines.join("\n")
      success(result)
    rescue => e
      errors.add(:base, "Failed to extract simple keywords: #{e.message}")
      failure
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

        # Create a new chunk every 8-10 transactions to balance cost vs accuracy
        if transaction_count >= 8
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

    private

    def transaction_line?(line)
      return false unless line.is_a?(String)

      # Simple heuristic to identify transaction lines
      line.match?(/\d{2}-[a-z]{3}-\d{4}/) || # Date pattern
      line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/) || # Amount pattern
      line.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)/i)
    end
  end
end
