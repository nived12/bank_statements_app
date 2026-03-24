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

    # Batch increment hits_count
    if matched_rule_ids.any?
      CategoryRule.where(id: matched_rule_ids.uniq).update_all("hits_count = hits_count + 1")
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
      txn["category_id"] = rule.category.parent_id
      txn["sub_category_id"] = rule.category_id
    else
      txn["category_id"] = rule.category_id
      txn["sub_category_id"] = nil
    end
    txn["category_confidence"] = 0.95
  end
end
