class StatementFile < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account
  has_one_attached :file
  has_many :transactions, dependent: :destroy

  # Cast as JSON (Ruby Hash <-> text)
  attribute :parsed_json, :json, default: {}
  attribute :redaction_map, :json, default: {}

  encrypts :parsed_json, deterministic: false
  encrypts :error_message, deterministic: false
  encrypts :redaction_map, deterministic: false


  validates :file, presence: true, on: :create
  validates :redaction_hmac, length: { maximum: 128 }, allow_blank: true
end
