# frozen_string_literal: true

##
# Goals::SuggestTransactionLinkingService
# TODO: PREMIUM FEATURE - AI-powered goal suggestion
#
# This service will use AI to analyze transaction descriptions and categories
# to suggest which goals the transaction should contribute to, with confidence scores.
#
# Planned functionality:
# - Analyze transaction description, category, and merchant
# - Compare against active goals' categories and names
# - Use AI to determine semantic similarity
# - Return suggested goals ranked by confidence
#
# Example usage (future):
#   result = Goals::SuggestTransactionLinkingService.call(transaction)
#   if result.success?
#     suggestions = result.payload
#     # suggestions = [
#     #   { goal: <Goal>, confidence: 0.95, reason: "Category match" },
#     #   { goal: <Goal>, confidence: 0.70, reason: "Merchant similarity" }
#     # ]
#   end
#
class Goals::SuggestTransactionLinkingService < ApplicationService
  def initialize(transaction, user: nil)
    super()
    @transaction = transaction
    @user = user || transaction&.user
  end

  def call
    # TODO: PREMIUM FEATURE - Implement AI-powered suggestion logic
    #
    # Implementation steps:
    # 1. Get all active goals for the user
    # 2. Analyze transaction (description, category, merchant, amount)
    # 3. Use AI API (OpenAI) to match transaction to goals
    # 4. Calculate confidence scores
    # 5. Return ranked suggestions
    #
    # For now, return basic category-based matching

    suggestions = basic_category_matching

    success(suggestions)
  end

  private

  attr_reader :transaction, :user

  # Basic non-AI matching (free tier)
  # This provides simple category-based suggestions without AI
  def basic_category_matching
    return [] unless transaction&.category_id

    # Find goals that have savings or debts with the same category
    matching_goals = user.goals
                         .active
                         .joins(:savings, :debts)
                         .joins("LEFT JOIN saving_categories ON savings.id = saving_categories.saving_id")
                         .joins("LEFT JOIN debt_categories ON debts.id = debt_categories.debt_id")
                         .where("saving_categories.category_id = ? OR debt_categories.category_id = ?", transaction.category_id, transaction.category_id)
                         .distinct
                         .map do |goal|
                           {
                             goal: goal,
                             confidence: 0.8, # Fixed confidence for basic matching
                             reason: "Category match (#{transaction.category.name})"
                           }
                         end

    matching_goals
  end

  # TODO: PREMIUM FEATURE - AI-powered matching
  # def ai_powered_matching
  #   return [] unless ai_enabled_for_user?
  #
  #   active_goals = user.goals.active
  #
  #   # Build context for AI
  #   context = build_ai_context(transaction, active_goals)
  #
  #   # Call AI API (OpenAI)
  #   ai_response = call_ai_api(context)
  #
  #   # Parse and rank suggestions
  #   parse_ai_suggestions(ai_response, active_goals)
  # end
  #
  # def ai_enabled_for_user?
  #   # Check if user has premium subscription
  #   user&.premium?
  # end

  def context_for_logging
    {
      transaction_id: transaction&.id,
      user_id: user&.id,
      premium_feature: true
    }
  end
end
