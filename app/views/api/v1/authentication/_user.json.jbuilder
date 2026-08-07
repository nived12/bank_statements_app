# frozen_string_literal: true

json.extract!(user, :id, :email, :first_name, :last_name, :full_name)
json.confirmed(user.confirmed?)
json.avatar_url(user.avatar_url)
json.legal_version_accepted(user.legal_version_accepted)
json.consent_current(user.legal_consent_current?)

# Subscription fields for mobile paywall logic (mirrors api/v1/users/_user.json.jbuilder)
statement_files_count = user.statement_files.count
subscription_result = user.subscription_access_result
if subscription_result[:allowed]
  if user.active_paid_subscription?
    json.subscription_status("active")
  else
    json.subscription_status("trial_active")
  end
else
  json.subscription_status(subscription_result[:reason]&.to_s || "none")
end
json.trial_ends_at(user.trial_ends_at&.iso8601)
# Asked of the user, not of a processor — Stripe and Apple both answer here.
json.subscription_interval(user.billing_interval&.to_s)
json.billing_source(user.billing_source)
json.ai_calls_used(user.quota.ai_usage_count)
ai_calls_limit = if user.active_paid_subscription?
  SubscriptionAccess.premium_monthly_ai_calls
else
  SubscriptionAccess.free_tier_ai_calls
end
json.ai_calls_limit(ai_calls_limit)
json.statement_files_used(statement_files_count)
json.statement_files_limit(SubscriptionAccess.free_tier_statement_files)
