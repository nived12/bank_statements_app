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

  # What this subscription is actually billed, in minor units, from the price Stripe
  # recorded. nil when there is no Stripe price behind it (manual grants).
  #
  # Callers must not substitute a configured list price when this is nil: a subscriber
  # sitting on a retired price is not paying today's number, and showing them today's
  # number is how the card ended up claiming $899 for an $1,188 subscription.
  def billing_amount_cents
    stripe_price&.dig("unit_amount")
  end

  private

  # The plan's price object as Pay synced it.
  #
  # Assumes a single line item, which holds today: every subscription is created with
  # one item (see the checkout call in Api::V1::SubscriptionsController). If a metered
  # add-on is ever added, this would silently read whichever item Stripe returns first
  # and would need to select by price id or product instead.
  def stripe_price
    object&.dig("items", "data", 0, "price")
  end

  # Authoritative: the interval Stripe itself recorded, synced into `object` by Pay.
  #
  # Reports :month for a quarterly plan, since Stripe encodes those as
  # interval "month" with interval_count 3. Vittio has no such price; revisit
  # here rather than at the call sites if one is ever added.
  def stripe_interval
    value = stripe_price&.dig("recurring", "interval")
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
