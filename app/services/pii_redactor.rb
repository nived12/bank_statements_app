require "openssl"

class PiiRedactor
  # Tokens we’ll inject into the text in place of PII
  TOKEN_FMT = "⟪PII:%s:%d⟫"

  # Order matters: put more specific patterns first
  PATTERNS = {
    email: /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i,
    # Liberal MX phone: allows spaces, dashes, parens, optional +52
    phone: /(?<!\d)(?:\+?52)?[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d(?!\d)/,
    # CLABE (18 digits, allow separators)
    clabe: /(?<!\d)(?:\d[\s-]?){18}(?!\d)/,
    # Card (16 digits, allow separators) – heuristic only
    card:  /(?<!\d)(?:\d[\s-]?){16}(?!\d)/,
    # RFC (simplified, PF/PM)
    rfc:   /\b[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{2,3}\b/i,
    # CURP
    curp:  /\b[A-Z][AEIOUX][A-Z]{2}\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])[HM][A-Z]{5}[A-Z0-9]\d\b/i,
    # IBAN-like (generic)
    iban:  /\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/i,
    # Very heuristic address fragments (street keywords)
    addr:  /\b(?:calle|av\.?|avenida|blvd\.?|boulevard|col\.?|colonia|cp|c\.p\.|mz\.?|manzana|lt\.?|lote)\b[^,\n]{0,60}/i
  }.freeze

  def initialize(secret: Rails.application.secret_key_base)
    @secret = secret
  end

  # Return [redacted_text, map(Hash token=>original), hmac(String)]
  def redact(text)
    map = {}
    redacted = text.dup
    seq = Hash.new(0)

    PATTERNS.each do |type, regex|
      redacted.gsub!(regex) do |match|
        seq[type] += 1
        token = TOKEN_FMT % [ type.to_s.upcase, seq[type] ]
        map[token] ||= match
        token
      end
    end

    [ redacted, map, hmac_for(redacted) ]
  end

  # Replace tokens back to original using the map
  def restore(text, map)
    return text if map.blank?
    out = text.dup
    map.each { |token, original| out.gsub!(token, original.to_s) }
    out
  end

  # Integrity: HMAC of the exact redacted payload
  def hmac_for(payload)
    OpenSSL::HMAC.hexdigest("SHA256", @secret, payload.to_s)
  end

  def valid_hmac?(payload, hmac)
    ActiveSupport::SecurityUtils.secure_compare(hmac.to_s, hmac_for(payload))
  end
end
