# frozen_string_literal: true

class AssistantMessage < ApplicationRecord
  ROLES = %w[user assistant system].freeze

  belongs_to :assistant_conversation
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true, length: { maximum: 4_000 }

  scope :for_month, ->(t = Time.current) { where(created_at: t.beginning_of_month..t.end_of_month) }
  scope :user_messages_billable, -> { where(role: "user") }
end
