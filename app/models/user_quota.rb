# frozen_string_literal: true

# Holds the unified AI usage counter and reset metadata for a user.
# One counter covers all AI surfaces: voice, camera, recurring suggestions, and assistant.
# Trial: one-time pool (FREE_TIER_AI_CALLS). Premium: monthly reset anchored on signup day.
# The `ai_usage_threshold_shown` column tracks the highest 80/90/95 threshold already notified.
class UserQuota < ApplicationRecord
  belongs_to :user
end

# == Schema Information
#
# Table name: user_quota
#
# Columns:
#  id                       :integer   not null   no default   no index
#  user_id                  :integer   not null   no default   index: index_user_quota_on_user_id (unique)
#  ai_usage_count           :integer   not null   default: 0   no index
#  ai_usage_reset_at        :datetime  null       no default   no index
#  ai_usage_anchor_day      :integer   null       no default   no index
#  ai_usage_threshold_shown :integer   not null   default: 0   no index
#  created_at               :datetime  not null   no default   no index
#  updated_at               :datetime  not null   no default   no index
