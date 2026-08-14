# app/services/pdf_parser/concerns/tracking_key.rb
module PdfParser
  module Concerns
    # Extracts the SPEI "clave de rastreo" — the tracking key Banxico assigns to an
    # interbank transfer. Both banks print the *same* key for the same operation, so
    # it pairs the two sides exactly: no date tolerance, no amount tolerance, no
    # description guessing. That matters because statements disagree about dates
    # (BBVA prints fecha de operación, Santander prints its posting date, 2-3 days
    # apart) and because equal amounts on one day are not rare enough to match on.
    #
    # A missed key costs nothing — the reconciler falls back to amount+date matching.
    # A *wrong* key would be expensive, so every pattern below is anchored to a form
    # seen on a real statement and the result must look like a key (see #plausible_key?).
    module TrackingKey
      # Banks that label the field. The label is matched case-insensitively; the value
      # is not, because claves are always uppercase and digits — letting the value go
      # case-insensitive would swallow ordinary prose that follows the label.
      LABELED_PATTERNS = [
        /(?i:CLAVE\s*DE\s*RASTREO)\s*:?\s*([A-Z0-9]{10,40})/,
        /(?i:CVE\s*RAST(?:REO)?)\s*:?\s*([A-Z0-9]{10,40})/
      ].freeze

      # BBVA prints the key on its own line with no label at all, directly beneath the
      # 18-digit CLABE — hence the digit/letter structure below rather than a loose
      # "long alphanumeric token", which would match the CLABE too.
      #
      # The STP tail is a fixed 18 characters, not an open-ended run, and there is no
      # closing \b: statement text runs the clave straight into the next word, so a
      # greedy tail consumed it and produced a key no other bank could ever match.
      UNLABELED_PATTERNS = [
        /\bMBAN\d{18,24}\b/,                 # BBVA:  MBAN01002607070086647893
        /\bREVO\d{8}[A-Z0-9]{18}/,           # STP:   REVO20260703IVSINBF4LTSNLLD85P
        /\b\d{13}[A-Z]{3,8}\d{6,}\b/         # SPEI:  2026071840014BMOVP000406328190
      ].freeze

      MINIMUM_DIGITS = 6

      # A clave sits a few lines below the row it belongs to, under the continuation
      # lines (CLABE, beneficiary, concept).
      AMOUNT_LOOKBACK_LINES = 8

      AMOUNT_PATTERN = /\b\d{1,3}(?:,\d{3})*\.\d{2}\b/

      # Maps each statement amount to the clave printed with it, for backfilling rows
      # imported before tracking keys were captured.
      #
      # Deliberately conservative: an amount that could belong to more than one clave
      # is dropped entirely rather than guessed. A missing key costs nothing — the
      # reconciler falls back to amount+date — whereas a *wrong* key would silently
      # pair two unrelated transactions as a transfer, which is exactly the class of
      # bug this work exists to remove.
      #
      # @param text [String] full statement text
      # @return [Hash{BigDecimal => String}] amount => clave, unambiguous entries only
      def tracking_keys_by_amount(text)
        return {} if text.blank?

        lines = text.to_s.split("\n")
        candidates = Hash.new { |hash, key| hash[key] = Set.new }
        previous_key_line = -1

        lines.each_with_index do |line, index|
          key = extract_tracking_key(line)
          next if key.blank?

          # The window starts after the previous clave — everything between two
          # claves belongs to the second one — and is capped so a distant amount
          # never gets dragged in.
          first = [previous_key_line + 1, index - AMOUNT_LOOKBACK_LINES].max
          lines[first..index].join(" ").scan(AMOUNT_PATTERN).each do |amount|
            candidates[BigDecimal(amount.delete(","))] << key
          end
          previous_key_line = index
        end

        candidates.filter_map { |amount, keys| [amount, keys.first] if keys.one? }.to_h
      end

      private

      # @param text [String, nil] the raw statement block for one transaction
      # @return [String, nil] the clave de rastreo, or nil when the row has none
      def extract_tracking_key(text)
        return if text.blank?

        LABELED_PATTERNS.each do |pattern|
          key = text[pattern, 1]
          return key if plausible_key?(key)
        end

        UNLABELED_PATTERNS.each do |pattern|
          key = text[pattern]
          return key if plausible_key?(key)
        end

        nil
      end

      # Guards against a label followed by prose ("CLAVE DE RASTREO TRANSFERENCIA")
      # and against all-numeric runs like the CLABE that sits beside the real key.
      def plausible_key?(key)
        return false if key.blank?

        digits = key.count("0-9")
        digits >= MINIMUM_DIGITS && digits < key.length
      end
    end
  end
end
