# frozen_string_literal: true

json.extract!(user, :id, :email, :first_name, :last_name)
json.full_name(user.full_name)
json.confirmed(user.confirmed?)
json.avatar_url(user.avatar_image.attached? ? url_for(user.avatar_image) : user.avatar_url)

# Subscription status for mobile paywall logic
# Possible values: "trial_active", "trial_ended", "active", "past_due", "none"
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
json.created_at(user.created_at&.iso8601)
json.updated_at(user.updated_at&.iso8601)
