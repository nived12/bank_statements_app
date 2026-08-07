# frozen_string_literal: true

json.extract!(user, :id, :email, :first_name, :last_name)
json.full_name(user.full_name)
json.confirmed(user.confirmed?)
json.avatar_url(user.avatar_image.attached? ? rails_blob_url(user.avatar_image, only_path: false) : user.avatar_url)

# Subscription status for mobile paywall logic
# Possible values: "trial_active", "trial_ended", "active", "past_due", "none"
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
json.statement_files_used(user.statement_files_count)
json.statement_files_limit(user.active_paid_subscription? ? nil : SubscriptionAccess.free_tier_statement_files)
json.legal_version_accepted(user.legal_version_accepted)
json.consent_current(user.legal_consent_current?)
json.created_at(user.created_at&.iso8601)
json.updated_at(user.updated_at&.iso8601)
