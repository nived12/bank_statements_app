require "openssl"

class PiiRedactor
  # Tokens we'll inject into the text in place of PII
  TOKEN_FMT = "⟪PII:%s:%d⟫"

  # Order matters: put more specific patterns first
  PATTERNS = {
    # Email addresses
    email: /\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b/i,

    # Phone numbers with context (after phone-related keywords)
    phone_context: /\b(?:telefono|tel|telefonica|celular|cel|movil|whatsapp|wa)\s*:?\s*(?:\d[\s\-()]*){8,}(?!\d)/i,

    # Account/Client numbers with context (flexible length - 6-12 digits)
    account: /\b(?:no\.?\s*de\s*(?:cuenta|cliente)|cuenta|cliente)\s*:?\s*(\d[\s\-]*){6,12}(?!\d)/i,

    # CLABE (18 digits, allow separators)
    clabe: /(?<!\d)(?:\d[\s-]?){18}(?!\d)/,

    # Card (16 digits, allow separators)
    card: /(?<!\d)(?:\d[\s-]?){16}(?!\d)/,

    # RFC (simplified, PF/PM)
    rfc: /\b[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{2,3}\b/i,

    # CURP - must come before big_alphanumeric
    curp: /\b[A-Z][A-Z]{2}\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])[HM][A-Z]{5}[A-Z0-9]\d\b/i,

    # IBAN-like (generic)
    iban: /\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/i,

    # Address patterns - only catch actual addresses, not transaction descriptions
    # Must start with address keywords to avoid false positives
    address: /\b(?:calle|av\.?|avenida|blvd\.?|boulevard|col\.?|colonia|cp|c\.p\.|mz\.?|manzana|lt\.?|lote|plaza)\b(?:\s+(?:del|de|la|el|las|los)\s+[A-Z][a-z]+(?:\s+[a-z]+)*)?[^,\n]{0,60}/i,

    # CLABE with context
    clabe_context: /\b(?:clabe|cuenta\s*clabe)\s*:?\s*(?:\d[\s-]?){18}(?!\d)/i,

    # CURP with context
    curp_context: /\b(?:curp)\s*:?\s*[A-Z][AEIOUX][A-Z]{2}\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])[HM][A-Z]{5}[A-Z0-9]\d\b/i,

    # RFC with context
    rfc_context: /\b(?:rfc)\s*:?\s*[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{2,3}\b/i,

    # IBAN with context
    iban_context: /\b(?:iban|cuenta\s*internacional)\s*:?\s*[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/i,

    # Card with context
    card_context: /\b(?:tarjeta|card|numero\s*de\s*tarjeta|num\.?\s*tarjeta)\s*:?\s*(?:\d[\s-]?){16}(?!\d)/i,

    # Address with context
    address_context: /\b(?:direccion|dir|domicilio|dom|domiciliado|domiciliada)\s*:?\s*(?:calle|av\.?|avenida|blvd\.?|boulevard|col\.?|colonia|cp|c\.p\.|mz\.?|manzana|lt\.?|lote)\b[^,\n]{0,60}/i,

    # Liberal MX phone: allows spaces, dashes, parens, optional +52 (fallback)
    phone: /(?<!\d)(?:\+?52)?[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d[\s\-()]*\d(?!\d)(?![A-Z])(?!\d{8,})/,

    # Long alphanumeric with specific prefixes (REF:, CIE:, etc.) - must come before big_alphanumeric
    prefixed_id: /\b(?:REF|CIE|GUIA|ID|NUMERO|REFERENCIA):[A-Z0-9]{10,}\b/i,

    # Huge numbers (20+ digits) - these are likely account numbers, references, etc.
    huge_number: /\b\d{20,}(?![,.])\b/,

    # Long alphanumeric strings (12+ chars) - only catch solid strings without spaces/prepositions
    # Avoids natural language phrases and transaction descriptions
    long_alphanumeric: /\b[A-Z0-9]{12,}(?![,.])\b/i
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

  # Special method for bank statements: redact PII while preserving transaction data
  def redact_preserving_transactions(text)
    # Use the same redaction logic but with patterns that preserve transaction data
    redact(text)
  end
end
