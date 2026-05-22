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

  def last_subject_present?
    last_subject.present? && last_subject.is_a?(Hash) && last_subject["type"].present?
  end

  def touch_last_message!
    update_columns(
      last_message_at: Time.current,
      message_count: messages.count,
      updated_at: Time.current
    )
  end
end

# == Schema Information
#
# Table name: assistant_conversations
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_assistant_conversations_on_user_id, index_assistant_conversations_on_user_id_and_last_message_at
#  title                :string          null       no default           no index
#  locale               :string          not null   default: es-MX       no index
#  last_message_at      :datetime        null       no default           index: index_assistant_conversations_on_user_id_and_last_message_at
#  message_count        :integer         not null   default: 0           no index
#  disclaimer_shown     :boolean         not null   default: false       no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_assistant_conversations_on_user_id (user_id) non-unique
#  index_assistant_conversations_on_user_id_and_last_message_at (user_id, last_message_at) non-unique
#
