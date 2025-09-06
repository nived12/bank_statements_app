module TransactionsHelper
  def confidence_badge(v)
    return "" if v.nil?
    val = (v.to_f * 100).round
    level = case v
    when 0.0..0.5 then "Low"
    when 0.5..0.8 then "Medium"
    else "High"
    end
    %Q(<span title="#{val}% confidence" style="font-size:12px;padding:2px 6px;border-radius:10px;border:1px solid #ccc;">AI #{level}</span>).html_safe
  end

  def render_sort_indicator(column)
    return "" unless @current_sort == column

    if @current_direction == "asc"
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

    # First, remove PII tokens and long alphanumeric references
    cleaned = description
      .gsub(/⟪PII:[^:]+:\d+⟫/, "")  # Remove PII tokens
      .gsub(/\b[A-Z0-9]{12,}\b/) { |match| match.match?(/[A-Z]/) && match.match?(/\d/) ? "" : match }  # Remove very long alphanumeric codes (12+ chars) that contain both letters and numbers
      .gsub(/\b\d{10,}\b/, "")  # Remove long numeric references (10+ digits)
      .gsub(/\b[A-Z]{2,}\d{6,}\b/, "")  # Remove patterns like SANT123456
      .gsub(/\b\d{6,}[A-Z]+\b/, "")  # Remove patterns like 1111111TRANSFERENCIA
      .gsub(/[+-]?[\d,]+\.\d{2}/, "")  # Remove amounts like 10,000.00 or -89.00
      .gsub(/\bREF:\d+\b/, "")  # Remove REF:12345 patterns
      .gsub(/\bTXN:[A-Z0-9]+\b/, "")  # Remove TXN:NET789 patterns
      .gsub(/\s+/, " ")  # Normalize whitespace
      .strip

    # Split into words and filter further
    words = cleaned.split(/\s+/)
    cleaned_words = []

    words.each_with_index do |word, index|
      # Keep the word if it meets any of these criteria:
      if should_keep_word_for_display?(word, words, index)
        cleaned_words << word
      end
    end

    cleaned_words.join(" ").strip
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
