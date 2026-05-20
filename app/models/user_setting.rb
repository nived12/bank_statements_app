# frozen_string_literal: true

class UserSetting < ApplicationRecord
  belongs_to :user

  ALLOWED_PREFERENCES = %w[
    processing_strategy
    notify_statement_imports
    notify_goal_milestones
    notify_debt_reminders
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
