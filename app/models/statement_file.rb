class StatementFile < ApplicationRecord
  # Technical error_message prefixes mapped to the copy shown to users.
  ERROR_MESSAGE_KEYS = {
    /password_required:/ => "statement_files.password_required_error",
    /processing_interrupted:/ => "statement_files.processing_interrupted",
    /finishReason: MAX_TOKENS/ => "statement_files.statement_too_long_error",
    /file_not_found:/ => "statement_files.file_not_found"
  }.freeze

  belongs_to :user
  belongs_to :bank_account
  has_one_attached :file
  has_many :transactions, dependent: :destroy
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

  # Processing strategy enum
  enum :processing_strategy, {
    parser_only: "parser_only",       # No AI, deterministic parser only
    text_with_ai: "text_with_ai",     # Text extraction + AI fallback (former ai_enabled behavior)
    vision_ai: "vision_ai"            # Skip text extraction, go directly to Vision API
  }, default: :parser_only

  # Native JSON columns (Ruby Hash <-> JSON)
  encrypts :parsed_json, deterministic: false
  encrypts :error_message, deterministic: false
  encrypts :redaction_map, deterministic: false

  # Encrypted file password (temporary - cleared after processing)
  encrypts :file_password, deterministic: false

  validates :file, presence: true, on: :create
  validates :bank_account_id, presence: true
  validates :user_id, presence: true
  validate :acceptable_file, on: :create
  validates :redaction_hmac, length: { maximum: 128 }, allow_blank: true
  validates :cutoff_date, presence: true, on: :create

  # Scopes
  scope :by_cutoff_date, ->(direction = :desc) {
    if direction.to_sym == :desc
      order(Arel.sql("cutoff_date DESC NULLS LAST"))
    else
      order(Arel.sql("cutoff_date ASC NULLS LAST"))
    end
  }

  # Safe method to get filename
  def safe_filename
    file.attached? ? file.filename.to_s : "No File Attached"
  end

  # True for statuses that represent successful processing
  def success?
    completed? || parsed?
  end

  def status_color
    return "green" if success?
    return "red" if error?

    "amber"
  end

  # Clear the file password after processing (security measure)
  def clear_password!
    update_column(:file_password, nil) if file_password.present?
  end

  # Check if the error indicates a password is required
  def password_required_error?
    error? && error_message.to_s.include?("password_required:")
  end

  # error_message stores the technical reason for diagnosis. Views render this
  # instead: a friendly line for causes the user can act on, and nil otherwise,
  # since the generic "processing failed" copy already covers the rest.
  def user_facing_error
    return unless error? && error_message.present?

    key = ERROR_MESSAGE_KEYS.find { |pattern, _| error_message.match?(pattern) }&.last
    I18n.t(key) if key
  end

  # Backward compatibility for existing code that uses ai_enabled?
  def ai_enabled?
    !parser_only?
  end

  private

  def acceptable_file
    return unless file.attached?

    # file.content_type is set by ActiveStorage via Marcel::MimeType.for(io) during blob
    # creation — it reads magic bytes, not just the client-supplied Content-Type header.
    unless file.content_type.in?(%w[application/pdf])
      errors.add(:file, "must be a PDF")
    end

    # 10 MB limit
    if file.byte_size > 10.megabytes
      errors.add(:file, "is too large (max 10 MB)")
    end
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
#  status               :integer         not null   default: 0           no index
#  cutoff_date          :datetime        null       no default           index: index_statement_files_on_cutoff_date
#  usage_metadata       :jsonb           null       default: {}          no index
#  processing_strategy  :string          not null   default: parser_only no index
#  file_password        :text            null       no default           no index
#
# Indexes:
#  index_statement_files_on_bank_account_id (bank_account_id) non-unique
#  index_statement_files_on_cutoff_date (cutoff_date) non-unique
#  index_statement_files_on_redaction_hmac (redaction_hmac) non-unique
#  index_statement_files_on_user_id (user_id) non-unique
#
