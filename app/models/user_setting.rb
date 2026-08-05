# frozen_string_literal: true

class UserSetting < ApplicationRecord
  belongs_to :user

  ALLOWED_PREFERENCES = %w[
    processing_strategy
    notify_statement_imports
    notify_goal_milestones
    notify_debt_reminders
    notify_recurring_due
    notify_trial_reminders
    analytics_enabled
    analytics_notice_seen_at
  ].freeze

  validates :user_id, uniqueness: true
  validate :validate_preferences_keys

  def processing_strategy
    preferences["processing_strategy"] || "vision_ai"
  end

  def processing_strategy=(value)
    self.preferences = preferences.merge("processing_strategy" => value)
  end

  def notify_statement_imports
    preferences.fetch("notify_statement_imports", true)
  end

  def notify_statement_imports=(value)
    self.preferences = preferences.merge("notify_statement_imports" => value)
  end

  def notify_goal_milestones
    preferences.fetch("notify_goal_milestones", true)
  end

  def notify_goal_milestones=(value)
    self.preferences = preferences.merge("notify_goal_milestones" => value)
  end

  def notify_debt_reminders
    preferences.fetch("notify_debt_reminders", true)
  end

  def notify_debt_reminders=(value)
    self.preferences = preferences.merge("notify_debt_reminders" => value)
  end

  def notify_recurring_due
    preferences.fetch("notify_recurring_due", true)
  end

  def notify_recurring_due=(value)
    self.preferences = preferences.merge("notify_recurring_due" => value)
  end

  # Email, not push — the only lifecycle mailer that is user-disableable.
  # Account confirmation and password reset are transactional and stay off this list.
  def notify_trial_reminders
    preferences.fetch("notify_trial_reminders", true)
  end

  def notify_trial_reminders=(value)
    self.preferences = preferences.merge("notify_trial_reminders" => ActiveModel::Type::Boolean.new.cast(value))
  end

  def analytics_enabled
    preferences.fetch("analytics_enabled", true)
  end

  def analytics_enabled=(value)
    self.preferences = preferences.merge("analytics_enabled" => ActiveModel::Type::Boolean.new.cast(value))
  end

  def analytics_notice_seen_at
    preferences["analytics_notice_seen_at"]
  end

  def analytics_notice_seen_at=(value)
    stamp =
      case value
      when true, "true", 1, "1" then Time.current.iso8601
      when false, "false", 0, "0", nil, "" then nil
      else value.to_s
      end
    self.preferences = preferences.merge("analytics_notice_seen_at" => stamp)
  end

  private

  def validate_preferences_keys
    invalid_keys = preferences.keys - ALLOWED_PREFERENCES
    if invalid_keys.any?
      errors.add(:preferences, "contains invalid keys: #{invalid_keys.join(", ")}")
    end
  end
end

# == Schema Information
#
# Table name: user_settings
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_user_settings_on_user_id
#  preferences          :jsonb           not null   default: {}          no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_user_settings_on_user_id (user_id) unique
#
