class CategoryRules::Matcher < ApplicationService
  def initialize(user:, transactions:)
    super()
    @user = user
    @transactions = transactions
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

    # Increment hits_count per rule proportional to actual match count
    matched_rule_ids.tally.each do |rule_id, count|
      CategoryRule.where(id: rule_id).update_all([ "hits_count = hits_count + ?", count ])
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
        normalized_description.include?(rule.pattern)
      when "starts_with"
        normalized_description.start_with?(rule.pattern)
      end
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
  end
end
