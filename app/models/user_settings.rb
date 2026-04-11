class UserSettings < ApplicationRecord
  belongs_to :user

  ALLOWED_PREFERENCES = %w[processing_strategy theme].freeze

  validates :user_id, uniqueness: true
  validate :validate_preferences_keys

  def processing_strategy
    preferences["processing_strategy"] || "vision_ai"
  end

  def processing_strategy=(value)
    self.preferences = preferences.merge("processing_strategy" => value)
  end

  def theme
    preferences["theme"] || "light"
  end

  def theme=(value)
    self.preferences = preferences.merge("theme" => value)
  end

  private

  def validate_preferences_keys
    invalid_keys = preferences.keys - ALLOWED_PREFERENCES
    if invalid_keys.any?
      errors.add(:preferences, "contains invalid keys: #{invalid_keys.join(", ")}")
    end
  end
end
