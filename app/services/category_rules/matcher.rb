class CategoryRules::Matcher < ApplicationService
  def initialize(user:, transactions:, record_hits: true)
    super()
    @user = user
    @transactions = transactions
    @record_hits = record_hits
  end

  def call
    rules = @user.category_rules.active.by_priority.includes(:category)
    return success(matched: [], unmatched: @transactions) if rules.empty? || @transactions.blank?

    matched = []
    unmatched = []
    matched_rule_ids = []

    @transactions.each do |txn|
      description = txn["description"] || txn[:description] || ""
      normalized = CategoryRules::DescriptionNormalizer.call(description)
      rule = find_matching_rule(normalized, rules)

      if rule
        apply_rule(txn, rule)
        matched << txn
        matched_rule_ids << rule.id
      else
        unmatched << txn
      end
    end

    # Increment hits_count per rule proportional to actual match count. The backfill
    # preview matches without applying anything, so it must not move the counter.
    if @record_hits
      matched_rule_ids.tally.each do |rule_id, count|
        CategoryRule.where(id: rule_id).update_all([ "hits_count = hits_count + ?", count ])
      end
    end

    success(matched: matched, unmatched: unmatched)
  end

  private

  def find_matching_rule(normalized_description, rules)
    return nil if normalized_description.blank?

    rules.detect do |rule|
      case rule.match_type
      when "exact"
        normalized_description == rule.pattern
      when "contains"
        contains?(normalized_description, rule.pattern)
      when "starts_with"
        normalized_description.start_with?(rule.pattern)
      end
    end
  end

  # A rule is learned from one extraction of a description, but the AI phrases the same
  # real transaction differently between imports — most often by keeping or dropping an
  # embedded account number. So "contains" accepts the pattern's words appearing in order
  # with gaps ("pago de prestamo total de recibo" vs "PAGO DE PRESTAMO 9837815631 TOTAL DE
  # RECIBO") on top of the plain substring, which short patterns like "oxxo" still rely on.
  # Deliberately not a similarity score: two loans at the same bank differ only by their
  # account number and score ~0.85 on trigrams, so any threshold loose enough to bridge the
  # gap above is also loose enough to merge two different debts.
  def contains?(normalized_description, pattern)
    return true if normalized_description.include?(pattern)

    words_in_order?(normalized_description.split, pattern.split)
  end

  def words_in_order?(description_words, pattern_words)
    remaining = description_words

    pattern_words.all? do |word|
      index = remaining.index(word)
      next false if index.nil?

      remaining = remaining[(index + 1)..]
      true
    end
  end

  def apply_rule(txn, rule)
    if rule.category.parent_id.present?
      parent_id = rule.category.parent_id
      child_id = rule.category_id
    else
      parent_id = rule.category_id
      child_id = nil
    end

    # Write both key formats to handle symbol-keyed and string-keyed transaction hashes
    [ :category_id, "category_id" ].each { |k| txn[k] = parent_id }
    [ :sub_category_id, "sub_category_id" ].each { |k| txn[k] = child_id }
    [ :category_confidence, "category_confidence" ].each { |k| txn[k] = 0.95 }
    [ :matched_rule_id, "matched_rule_id" ].each { |k| txn[k] = rule.id }
  end
end
