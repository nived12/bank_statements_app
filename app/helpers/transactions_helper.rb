module TransactionsHelper
  ALLOWED_RETURN_KEYS = %w[bank_account_id statement_file_id transaction_type from_date to_date search sort direction
page category_ids].freeze

  # Returns a filtered query string containing only allowlisted filter/sort keys,
  # safe to embed in data attributes that will be round-tripped back to the server.
  def safe_return_query_string
    Rack::Utils.parse_nested_query(request.query_string)
               .slice(*ALLOWED_RETURN_KEYS)
               .to_query
  end

  # Builds the return URL for the transactions index, restoring filter params if present.
  def transactions_return_path(return_to)
    return transactions_path if return_to.blank?

    parsed = Rack::Utils.parse_nested_query(return_to).slice(*ALLOWED_RETURN_KEYS)
    transactions_path(parsed)
  rescue StandardError
    transactions_path
  end

  def confidence_badge(v)
    return "" if v.nil?

    val = (v.to_f * 100).round
    level = case v
    when 0.0..0.5 then "Low"
    when 0.5..0.8 then "Medium"
    else "High"
    end
    # rubocop:disable Layout/LineLength
    %Q(<span title="#{val}% confidence" style="font-size:12px;padding:2px 6px;border-radius:10px;border:1px solid #ccc;">AI #{level}</span>).html_safe
    # rubocop:enable Layout/LineLength
  end

  def render_sort_indicator(column, current_sort = nil, current_direction = nil)
    # Use instance variables as fallback for backward compatibility
    current_sort ||= @current_sort
    current_direction ||= @current_direction

    return "" unless current_sort == column

    if current_direction == "asc"
      # Up arrow for ascending
      '<svg class="inline w-4 h-4 ml-1 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
      </svg>'.html_safe
    else
      # Down arrow for descending
      '<svg class="inline w-4 h-4 ml-1 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
      </svg>'.html_safe
    end
  end

  def short_description(description, max_length = 60)
    return "" if description.blank?

    # Clean up the description for display
    cleaned = clean_description_for_display(description)

    # Truncate if too long
    if cleaned.length > max_length
      cleaned[0...max_length] + "..."
    else
      cleaned
    end
  end

  private

  def clean_description_for_display(description)
    return "" if description.blank?

    # Extract meaningful parts from the description
    cleaned = description.dup

    # Remove PII tokens
    cleaned.gsub!(/⟪PII:[^:]+:\d+⟫/, "")

    # Remove common technical codes and references (bank-agnostic)
    # Remove patterns like SPEIBCO:012BENEF, SANT123456, etc.
    cleaned.gsub!(/\b[A-Z]{2,}\d{6,}\b/, "")
    cleaned.gsub!(/\b\d{6,}[A-Z]+\b/, "")
    cleaned.gsub!(/\b[A-Z0-9]{12,}\b/) { |match| match.match?(/[A-Z]/) && match.match?(/\d/) ? "" : match }
    cleaned.gsub!(/\b\d{10,}\b/, "")
    cleaned.gsub!(/[+-]?[\d,]+\.\d{2}/, "")
    cleaned.gsub!(/\b(?:REF|TXN|CVE|RFC|CLABE):[A-Z0-9]+\b/, "")
    cleaned.gsub!(/\([^)]*VERIF[^)]*\)/i, "")
    cleaned.gsub!(/\([^)]*DATONOVERIF[^)]*\)/i, "")
    cleaned.gsub!(/\([^)]*HORALIQ[^)]*\)/i, "")
    cleaned.gsub!(/CVERASTREO:\s*\d+[A-Z]\d+/, "")
    cleaned.gsub!(/\.\d+[A-Z]+HORALIQ:\d+:\d+:\d+/, "")

    # Remove common bank-specific patterns (but keep merchant names)
    cleaned.gsub!(/SPEIBCO:\d+BENEF:/, "")  # Remove SPEIBCO:012BENEF: prefix but keep what follows
    cleaned.gsub!(/\(DATONOVERIFPORESTAINST\)/, "")  # Remove verification text
    cleaned.gsub!(/,$/, "")  # Remove trailing commas
    cleaned.gsub!(/^,/, "")  # Remove leading commas
    cleaned.gsub!(/:$/, "")  # Remove trailing colons
    cleaned.gsub!(/^:/, "")  # Remove leading colons
    cleaned.gsub!(/\s+/, " ")  # Normalize whitespace
    cleaned.strip

    # If we have meaningful content, return it
    if cleaned.length > 3
      cleaned
    else
      # Fallback: return first 50 characters
      description[0..49].strip
    end
  end

  def should_keep_word_for_display?(word, words = nil, index = nil)
    return false if word.blank?

    # Remove standalone punctuation
    return false if word.match?(/^[+\-*.,:;]+$/)

    # Handle single digits - keep them if they're part of merchant names
    if word.length == 1 && word.match?(/^\d$/)
      # Keep if followed by a word that starts with a letter (like "7 ELEVEN")
      if words && index && index + 1 < words.length
        next_word = words[index + 1]
        if next_word && next_word.match?(/^[A-Z]/)
          return true
        end
      end
      # Remove standalone single digits
      return false
    end

    # Remove very short meaningless strings (but not single digits, handled above)
    return false if word.length < 2

    # Remove words that contain big numbers or alphanumeric codes (the main filtering logic)
    if should_remove_word?(word)
      return false
    end

    # Keep everything else (no length restrictions)
    true
  end

  def should_remove_word?(word)
    # Remove very long alphanumeric codes (12+ chars) that contain both letters and numbers
    if word.match?(/\b[A-Z0-9]{12,}\b/) && word.match?(/[A-Z]/) && word.match?(/\d/)
      return true
    end

    # Remove long numeric references (10+ digits)
    if word.match?(/^\d{10,}$/)
      return true
    end

    # Remove patterns like SANT123456 (letters + 6+ digits)
    if word.match?(/^[A-Z]{2,}\d{6,}$/)
      return true
    end

    # Remove patterns like 1111111TRANSFERENCIA (6+ digits + letters)
    if word.match?(/^\d{6,}[A-Z]+$/)
      return true
    end

    # Remove PII tokens
    if word.match?(/^⟪PII:[^:]+:\d+⟫$/)
      return true
    end

    # Remove reference patterns
    if word.match?(/^(REF|TXN):[A-Z0-9]+$/)
      return true
    end

    # Remove amounts
    if word.match?(/^[+-]?[\d,]+\.\d{2}$/)
      return true
    end

    # Keep everything else
    false
  end
end
