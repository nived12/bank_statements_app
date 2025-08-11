class StatementFile < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account
  has_one_attached :file

  # Cast as JSON (Ruby Hash <-> text)
  attribute :parsed_json, :json, default: {}

  # Encrypt sensitive fields (no :type option here)
  encrypts :parsed_json, deterministic: false
  encrypts :error_message, deterministic: false

  validates :file, presence: true, on: :create
end
