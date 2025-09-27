class StatementFile < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account
  has_one_attached :file
  has_many :transactions, dependent: :restrict_with_error
  has_many :pending_transactions, dependent: :destroy
  has_one :financial_summary, class_name: "StatementFinancialSummary", dependent: :destroy
  has_one :bank, through: :bank_account

  # Status enum
  enum :status, {
    pending: 0,
    processing: 1,
    parsed: 2,
    completed: 3,
    error: 4
  }

  # Native JSON columns (Ruby Hash <-> JSON)
  encrypts :parsed_json, deterministic: false
  encrypts :error_message, deterministic: false
  encrypts :redaction_map, deterministic: false

  validates :file, presence: true, on: :create
  validates :bank_account_id, presence: true
  validates :user_id, presence: true
  validates :redaction_hmac, length: { maximum: 128 }, allow_blank: true

  # Safe method to check if file is attached
  def file_safe?
    file.attached?
  end

  # Safe method to get filename
  def safe_filename
    file.attached? ? file.filename.to_s : "No File Attached"
  end

  # Check if the bank supports the account type for this statement
  def supported_bank_account_type?
    bank.supports_account_type?(bank_account.account_type)
  end
end

# == Schema Information
#
# Table name: statement_files
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_account_id      :integer         not null   no default           index: index_statement_files_on_bank_account_id
#  processed_at         :datetime        null       no default           no index
#  parsed_json          :jsonb           null       default: {}          no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  error_message        :text            null       no default           no index
#  user_id              :integer         not null   no default           index: index_statement_files_on_user_id
#  redaction_map        :jsonb           null       default: {}          no index
#  redaction_hmac       :string          null       no default           index: index_statement_files_on_redaction_hmac
#  ai_enabled           :boolean         not null   default: true        no index
#  status               :integer         not null   default: 0           no index
#
# Indexes:
#  index_statement_files_on_bank_account_id (bank_account_id) non-unique
#  index_statement_files_on_redaction_hmac (redaction_hmac) non-unique
#  index_statement_files_on_user_id (user_id) non-unique
#
