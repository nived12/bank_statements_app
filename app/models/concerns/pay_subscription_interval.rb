# frozen_string_literal: true

# Answers "is this subscription billed monthly or yearly?" for a Pay::Subscription.
#
# The obvious implementation — compare processor_plan against the current annual
# price ID — is wrong, and was live in four places. Stripe Prices are immutable, so
# changing the price means creating a new one and repointing the env var; every
# subscription created on the old price then compares false and silently reports
# monthly. It breaks precisely when it matters: after a price change, for the
# customers who have been paying longest.
#
# Instead, ask the subscription itself. Nothing here needs updating when prices
# rotate, and no Stripe API call is involved — a lookup would land in
# api/v1/.../_user.json.jbuilder, which renders on every login.
module PaySubscriptionInterval
  # Number of days above which a billing period is treated as annual. Monthly
  # periods run 28-31 days and annual ones 365-366, so anything near this is
  # unambiguous.
  ANNUAL_PERIOD_THRESHOLD_DAYS = 180

  # @return [Symbol, nil] :year, :month, or nil when the subscription has no
  #   Stripe price behind it (manually granted comp accounts) and therefore no
  #   billing interval to report.
  def billing_interval
    stripe_interval || inferred_interval
  end

  def annual?
    billing_interval == :year
  end

  private

  # Authoritative: the interval Stripe itself recorded, synced into `object` by Pay.
  #
  # Reports :month for a quarterly plan, since Stripe encodes those as
  # interval "month" with interval_count 3. Vittio has no such price; revisit
  # here rather than at the call sites if one is ever added.
  def stripe_interval
    value = object&.dig("items", "data", 0, "price", "recurring", "interval")
    return unless %w[month year].include?(value)

    value.to_sym
  end

  # Fallback for rows Pay tracked periods for but never stored the full object on.
  def inferred_interval
    return unless current_period_start && current_period_end

    span = (current_period_end.to_date - current_period_start.to_date).to_i
    span > ANNUAL_PERIOD_THRESHOLD_DAYS ? :year : :month
  end
end
