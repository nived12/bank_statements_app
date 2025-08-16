class User < ApplicationRecord
  has_secure_password

  has_many :bank_accounts, dependent: :destroy
  has_many :statement_files, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :categories, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  after_create :create_default_categories

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def ensure_default_categories
    # Check if user has meaningful categories (not just "Uncategorized")
    meaningful_categories = categories.where.not(name: "Uncategorized")
    return if meaningful_categories.exists?
    create_default_categories
  end

  private

  def create_default_categories
    CategoryTemplate.create_categories_for_user(self)
  end
end

# == Schema Information
#
# Table name: users
#
# Columns:
#  id                   :integer         not null   no default           no index
#  first_name           :string          not null   no default           no index
#  last_name            :string          not null   no default           no index
#  email                :string          not null   no default           index: index_users_on_email
#  password_digest      :string          null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_users_on_email           (email) unique
#
