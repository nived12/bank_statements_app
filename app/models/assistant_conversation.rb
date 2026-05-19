# frozen_string_literal: true

class AssistantConversation < ApplicationRecord
  LOCALES = %w[es-MX en].freeze

  belongs_to :user
  has_many :messages, -> { order(:created_at) },
    class_name: "AssistantMessage",
    dependent: :destroy

  validates :locale, inclusion: { in: LOCALES }
  validates :title, length: { maximum: 120 }, allow_nil: true

  scope :recent, -> { order(last_message_at: :desc, created_at: :desc) }

  def touch_last_message!
    update_columns(
      last_message_at: Time.current,
      message_count: messages.count,
      updated_at: Time.current
    )
  end
end
