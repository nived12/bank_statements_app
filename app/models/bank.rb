# app/models/bank.rb
class Bank < ApplicationRecord
  has_many :bank_accounts, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  # Enum for supported account types
  enum :supported_type, {
    debit: 1,      # Only debit/savings accounts supported
    credit: 2,     # Only credit accounts supported
    both: 3        # Both debit and credit accounts supported
  }, prefix: :supports

  scope :supported, -> { where.not(supported_type: nil) }
  scope :active, -> { where(active: true) }

  def self.supported_banks
    supported.active.order(:name)
  end

  def self.find_by_code_or_name(identifier)
    return unless identifier.present?

    # First try to find by exact code match
    bank = find_by(code: identifier.to_s.downcase.strip)
    return bank if bank

    # Then try to find by name (case insensitive)
    find_by("LOWER(name) = ?", identifier.to_s.downcase.strip)
  end

  def supported_for_parsing?
    supported_type.present? && active
  end

  # Check if bank supports a specific account type
  def supports_account_type?(account_type)
    return false unless supported_type.present?

    case account_type.to_s.downcase
    when "debit", "savings", "checking"
      supports_debit? || supports_both?
    when "credit"
      supports_credit? || supports_both?
    else
      false
    end
  end

  # Get the appropriate parsing strategy based on support
  def parsing_strategy_for_account_type(account_type)
    if supports_account_type?(account_type)
      :hybrid  # Use parser + AI enhancement
    else
      :ai_only  # Use AI only for unsupported types
    end
  end
end

# == Schema Information
#
# Table name: banks
#
# Columns:
#  id                   :integer         not null   no default           no index
#  code                 :string          not null   no default           index: index_banks_on_code
#  name                 :string          not null   no default           no index
#  active               :boolean         not null   default: true        no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  supported_type       :integer         null       no default           no index
#
# Indexes:
#  index_banks_on_code            (code) unique
#
