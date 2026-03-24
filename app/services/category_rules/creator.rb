class CategoryRules::Creator < ApplicationService
  def initialize(transaction)
    super()
    @transaction = transaction
  end

  def call
    return failure("No category assigned") if @transaction.category_id.blank?

    pattern = CategoryRules::DescriptionNormalizer.call(@transaction.description)
    return failure("Empty pattern after normalization") if pattern.blank?

    rule = CategoryRule.find_or_initialize_by(
      user_id: @transaction.user_id,
      pattern: pattern,
      match_type: :contains
    )

    rule.category_id = @transaction.category_id
    rule.auto_generated = true unless rule.persisted?
    rule.active = true

    if rule.save
      success(rule)
    else
      rule.errors.each { |error| errors.add(error.attribute, error.message) }
      failure
    end
  end
end
