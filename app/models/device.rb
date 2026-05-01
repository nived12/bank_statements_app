# frozen_string_literal: true

class Device < ApplicationRecord
  belongs_to :user

  PLATFORMS = %w[ios android web].freeze

  validates :push_token, presence: true, uniqueness: { scope: :user_id }
  validates :platform, presence: true, inclusion: { in: PLATFORMS }

  scope :active, -> { where(active: true) }
end
