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

    # Split into words and filter
    words = description.split(/\s+/)
    cleaned_words = []

    words.each do |word|
      # Keep the word if it meets any of these criteria:
      if should_keep_word_for_display?(word)
        cleaned_words << word
      end
    end

    cleaned_words.join(" ").strip
  end

  def should_keep_word_for_display?(word)
    return false if word.blank?

    # Keep reference numbers and alphanumeric codes (but not phone numbers or pure letters)
    if word.match?(/^[A-Z0-9]{8,}$/) && word.match?(/\d/) && word.match?(/[A-Z]/) || word.match?(/^[0-9]{10,}$/)
      # This looks like a reference number or code (must contain both letters and numbers)
      return true
    end

    # Keep words that are 8 characters or less (more restrictive)
    if word.length <= 8
      return true
    end

    # Keep common banking terms even if they're long
    banking_terms = [
      "PORTABILIDAD", "NOMINA", "INTERBANCARIO", "TARJETA", "CREDITO",
      "DEPOSITO", "RETIRO", "APARTADO"
    ]

    if banking_terms.any? { |term| word.upcase.include?(term) }
      return true
    end

    # Keep company names that are commonly seen
    company_names = [
      "APPTEGY", "BANAMEX", "BANORTE", "BANREGIO", "INFONAVIT"
    ]

    if company_names.any? { |company| word.upcase.include?(company) }
      return true
    end

    # Remove all words over 8 characters unless they're important
    false
  end
end
