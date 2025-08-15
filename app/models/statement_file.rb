class StatementFile < ApplicationRecord
  belongs_to :user
  belongs_to :bank_account
  has_one_attached :file
  has_many :transactions, dependent: :destroy
  has_one :financial_summary, class_name: "StatementFinancialSummary", dependent: :destroy

  # Native JSON columns (Ruby Hash <-> JSON)
  encrypts :parsed_json, deterministic: false
  encrypts :error_message, deterministic: false
  encrypts :redaction_map, deterministic: false

  validates :file, presence: true, on: :create
  validates :redaction_hmac, length: { maximum: 128 }, allow_blank: true
end

# == Schema Information
#
# Table name: statement_files
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_account_id      :integer         not null   no default           index: index_statement_files_on_bank_account_id
#  status               :string          null       no default           no index
#  processed_at         :datetime        null       no default           no index
#  parsed_json          :jsonb           null       default: {}          no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  error_message        :text            null       no default           no index
#  user_id              :integer         not null   no default           index: index_statement_files_on_user_id
#  redaction_map        :jsonb           null       default: {}          no index
#  redaction_hmac       :string          null       no default           index: index_statement_files_on_redaction_hmac
#
# Indexes:
#  index_statement_files_on_bank_account_id (bank_account_id) non-unique
#  index_statement_files_on_redaction_hmac (redaction_hmac) non-unique
#  index_statement_files_on_user_id (user_id) non-unique
#
