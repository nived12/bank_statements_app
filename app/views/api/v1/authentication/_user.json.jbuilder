# frozen_string_literal: true

json.extract!(user, :id, :email, :first_name, :last_name, :full_name)
json.confirmed(user.confirmed?)
json.avatar_url(user.avatar_url)
json.legal_version_accepted(user.legal_version_accepted)
json.consent_current(user.legal_consent_current?)

# Subscription fields for mobile paywall logic (mirrors api/v1/users/_user.json.jbuilder)
subscription_result = user.subscription_access_result
if subscription_result[:allowed]
  if user.trial_ends_at.present? && user.trial_ends_at > Time.current
    json.subscription_status("trial_active")
  else
    json.subscription_status("active")
  end
else
  json.subscription_status(subscription_result[:reason]&.to_s || "none")
end
json.trial_ends_at(user.trial_ends_at&.iso8601)
json.ai_calls_used(user.ai_usage_count)
json.ai_calls_limit(SubscriptionAccess.free_tier_ai_calls)
json.statement_files_used(user.statement_files.count)
json.statement_files_limit(SubscriptionAccess.free_tier_statement_files)
