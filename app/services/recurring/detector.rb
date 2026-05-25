# frozen_string_literal: true

##
# Recurring::Detector
#
# Detects recurring transaction patterns for a given user. Matches on a
# normalized DESCRIPTION (not merchant), with merchant used only as a
# confidence booster. Rejects variable-amount and irregular-cadence groups,
# so noisy patterns like Amazon do not get flagged.
#
# Usage:
#   Recurring::Detector.new(user).call
#
# Returns: Array of RecurringSeries persisted with status: "detected".
#
class Recurring::Detector
  LOOKBACK_DAYS       = 365
  MIN_OCCURRENCES     = 3
  MIN_SPAN_DAYS       = 45
  MAX_AMOUNT_CV       = 0.15 # std/mean
  MIN_CADENCE_FIT_PCT = 0.75
  SURFACE_THRESHOLD   = 65

  CADENCE_BANDS = {
    "weekly"    => (6..8),
    "biweekly"  => (13..16),
    "monthly"   => (27..33),
    "quarterly" => (86..95),
    "annual"    => (358..372)
  }.freeze

  CADENCE_DAYS = {
    "weekly" => 7, "biweekly" => 14, "monthly" => 30,
    "quarterly" => 91, "annual" => 365
  }.freeze

  SCORE_WEIGHTS = { amount: 40, cadence: 30, occurrences: 15, recency: 10, merchant: 5 }.freeze

  NOISE_TOKENS = %w[
    compra pago tdc tdd pos mx usa us card tarjeta
    purchase payment debit credit online www http https
    ref no num auth aut
  ].to_set.freeze

  def initialize(user)
    @user = user
  end

  def call
    created = []
    grouped_transactions.each do |signature, txns|
      next if txns.size < MIN_OCCURRENCES
      next if span_days(txns) < MIN_SPAN_DAYS

      amounts = txns.map { |t| t.amount.to_f.abs }
      cv = coefficient_of_variation(amounts)
      next if cv > MAX_AMOUNT_CV

      dates = txns.map(&:date).sort
      cadence, fit_pct = classify_cadence(dates)
      next if cadence.nil? || fit_pct < MIN_CADENCE_FIT_PCT

      score = score_group(
        cv:, fit_pct:, count: txns.size, last_date: dates.last,
        cadence:, merchant_consistent: merchant_consistent?(txns)
      )
      next if score < SURFACE_THRESHOLD

      series = upsert_series(signature:, txns:, cadence:, score:, amounts:)
      backfill_links(series, txns)
      created << series
    end
    created
  end

  private

  attr_reader :user

  def grouped_transactions
    txns = user.transactions
                .where(transaction_type: %w[fixed_expense variable_expense income])
                .where(recurring_series_id: nil)
                .where("date >= ?", LOOKBACK_DAYS.days.ago.to_date)
                .order(:date)
    txns.group_by { |t| normalize_description(t.description) }
        .reject { |sig, _| sig.blank? }
  end

  def normalize_description(str)
    return "" if str.blank?

    s = I18n.transliterate(str.to_s).downcase
    s = s.gsub(/[^a-z0-9 ]/, " ")           # punctuation -> space
    s = s.gsub(/\b\d+\b/, " ")               # standalone digits
    tokens = s.split.reject { |t| t.length < 3 || NOISE_TOKENS.include?(t) || t.match?(/\A\d/) }
    tokens.first(3).join(" ").strip
  end

  def span_days(txns)
    dates = txns.map(&:date)
    (dates.max - dates.min).to_i
  end

  def coefficient_of_variation(values)
    return 0.0 if values.empty?

    mean = values.sum / values.size.to_f
    return 0.0 if mean.zero?

    variance = values.sum { |v| (v - mean)**2 } / values.size
    Math.sqrt(variance) / mean
  end

  def classify_cadence(dates)
    return [nil, 0.0] if dates.size < 2

    gaps = dates.each_cons(2).map { |a, b| (b - a).to_i }
    best = CADENCE_BANDS.map do |name, band|
      in_band = gaps.count { |g| band.cover?(g) }
      [name, in_band.to_f / gaps.size]
    end.max_by { |(_, pct)| pct }
    best || [nil, 0.0]
  end

  def merchant_consistent?(txns)
    merchants = txns.map(&:merchant).compact_blank.map { |m| m.downcase.strip }
    return false if merchants.empty?

    merchants.uniq.size == 1
  end

  def score_group(cv:, fit_pct:, count:, last_date:, cadence:, merchant_consistent:)
    amount_pts   = (SCORE_WEIGHTS[:amount] * (1 - (cv / MAX_AMOUNT_CV))).clamp(0, SCORE_WEIGHTS[:amount])
    cadence_pts  = SCORE_WEIGHTS[:cadence] * fit_pct
    count_pts    = SCORE_WEIGHTS[:occurrences] * [count / 6.0, 1.0].min
    recency_pts  = recency_within_one_interval?(last_date, cadence) ? SCORE_WEIGHTS[:recency] : 0
    merchant_pts = merchant_consistent ? SCORE_WEIGHTS[:merchant] : 0
    (amount_pts + cadence_pts + count_pts + recency_pts + merchant_pts).round
  end

  def recency_within_one_interval?(last_date, cadence)
    (Date.current - last_date).to_i <= CADENCE_DAYS[cadence] + 5
  end

  def upsert_series(signature:, txns:, cadence:, score:, amounts:)
    mean_amount = (amounts.sum / amounts.size).round(2)
    last_date = txns.map(&:date).max
    next_due = last_date + CADENCE_DAYS[cadence].days
    most_common_category = txns.group_by(&:category_id).max_by { |_, v| v.size }&.first
    merchant_hint = txns.map(&:merchant).compact_blank.first
    name = txns.map(&:description).compact_blank.first || signature

    attempts = 0
    begin
      series = user.recurring_series.find_or_initialize_by(description_signature: signature)
      series.assign_attributes(
        name: name.truncate(120),
        merchant_hint: merchant_hint&.truncate(120),
        expected_amount: mean_amount,
        frequency: cadence,
        next_due_date: next_due,
        last_charged_at: last_date,
        category_id: most_common_category,
        transaction_type: txns.first.transaction_type,
        status: series.persisted? ? series.status : "detected",
        source: series.persisted? ? series.source : "detected",
        confidence_score: score,
        occurrences_count: txns.size,
        detected_at: series.detected_at || Time.current
      )
      series.save!
      series
    rescue ActiveRecord::RecordNotUnique
      # Concurrent detector run for the same user persisted this signature first.
      # Reload and continue; one retry is enough because the row now exists.
      attempts += 1
      retry if attempts < 2
      user.recurring_series.find_by!(description_signature: signature)
    end
  end

  def backfill_links(series, txns)
    Transaction.where(id: txns.map(&:id)).update_all(recurring_series_id: series.id)
  end
end
