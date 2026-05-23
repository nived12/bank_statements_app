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

# == Schema Information
#
# Table name: assistant_messages
#
# Columns:
#  id                   :integer         not null   no default           no index
#  assistant_conversation_id :integer         not null   no default           index: idx_asst_msgs_on_conv
#  user_id              :integer         not null   no default           index: index_assistant_messages_on_user_id, index_assistant_messages_on_user_id_and_created_at
#  role                 :string          not null   no default           no index
#  content              :text            not null   no default           no index
#  intent               :string          null       no default           no index
#  is_deterministic     :boolean         not null   default: false       index: index_assistant_messages_on_is_deterministic_and_created_at
#  prompt_tokens        :integer         null       default: 0           no index
#  completion_tokens    :integer         null       default: 0           no index
#  latency_ms           :integer         null       no default           no index
#  cost_usd             :decimal         null       default: 0.0         no index
#  provider             :string          null       no default           no index
#  model                :string          null       no default           no index
#  context_snapshot     :jsonb           null       default: {}          no index
#  next_best_action     :jsonb           null       default: {}          no index
#  tools_called         :jsonb           null       default: []          no index
#  created_at           :datetime        not null   no default           index: index_assistant_messages_on_is_deterministic_and_created_at, index_assistant_messages_on_user_id_and_created_at
#  updated_at           :datetime        not null   no default           no index

# == Schema Information
#
# Table name: assistant_messages
#
# Columns:
#  id                   :integer         not null   no default           no index
#  assistant_conversation_id :integer         not null   no default           index: idx_asst_msgs_on_conv
#  user_id              :integer         not null   no default           index: index_assistant_messages_on_user_id, index_assistant_messages_on_user_id_and_created_at
#  role                 :string          not null   no default           no index
#  content              :text            not null   no default           no index
#  intent               :string          null       no default           no index
#  is_deterministic     :boolean         not null   default: false       index: index_assistant_messages_on_is_deterministic_and_created_at
#  prompt_tokens        :integer         null       default: 0           no index
#  completion_tokens    :integer         null       default: 0           no index
#  latency_ms           :integer         null       no default           no index
#  cost_usd             :decimal         null       default: 0.0         no index
#  provider             :string          null       no default           no index
#  model                :string          null       no default           no index
#  context_snapshot     :jsonb           null       default: {}          no index
#  next_best_action     :jsonb           null       default: {}          no index
#  created_at           :datetime        not null   no default           index: index_assistant_messages_on_is_deterministic_and_created_at, index_assistant_messages_on_user_id_and_created_at
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  idx_asst_msgs_on_conv          (assistant_conversation_id) non-unique
#  index_assistant_messages_on_is_deterministic_and_created_at (is_deterministic, created_at) non-unique
#  index_assistant_messages_on_user_id (user_id) non-unique
#  index_assistant_messages_on_user_id_and_created_at (user_id, created_at) non-unique
#
