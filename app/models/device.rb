# frozen_string_literal: true

class Device < ApplicationRecord
  belongs_to :user

  PLATFORMS = %w[ios android web].freeze

  validates :push_token, presence: true, uniqueness: { scope: :user_id }
  validates :platform, presence: true, inclusion: { in: PLATFORMS }

  scope :active, -> { where(active: true) }
end

# == Schema Information
#
# Table name: devices
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_devices_on_user_id, index_devices_on_user_id_and_push_token
#  push_token           :string          not null   no default           index: index_devices_on_push_token, index_devices_on_user_id_and_push_token
#  platform             :string          not null   no default           no index
#  active               :boolean         not null   default: true        no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_devices_on_push_token    (push_token) non-unique
#  index_devices_on_user_id       (user_id) non-unique
#  index_devices_on_user_id_and_push_token (user_id, push_token) unique
#
