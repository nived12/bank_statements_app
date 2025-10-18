class User < ApplicationRecord
  has_secure_password

  has_many :bank_accounts, dependent: :destroy
  has_many :statement_files, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :goals, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :provider, presence: true, if: -> { provider.present? }
  validates :uid, presence: true, if: -> { provider.present? }
  validates :provider, uniqueness: { scope: :uid }, if: -> { provider.present? && uid.present? }

  after_create :create_default_categories

  def full_name
    "#{first_name&.strip} #{last_name&.strip}".strip
  end

  def oauth_user?
    provider.present? && uid.present?
  end

  def avatar_url
    super || default_avatar_url
  end

  def default_avatar_url
    # Return a default avatar URL using the user's initials
    initials = "#{first_name&.first}#{last_name&.first}".upcase
    "https://ui-avatars.com/api/?name=#{initials}&size=150&background=cccccc&color=ffffff"
  end

  def self.find_or_create_from_oauth(auth)
    # Find existing OAuth user
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # Find existing user by email and link OAuth account
    existing_user = find_by(email: auth.info.email)
    if existing_user
      existing_user.update!(
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: auth.info.image,
        first_name: auth.info.given_name || auth.info.name.split.first,
        last_name: auth.info.family_name || auth.info.name.split.last
      )
      return existing_user
    end

    # Create new OAuth user
    create!(
      email: auth.info.email,
      provider: auth.provider,
      uid: auth.uid,
      avatar_url: auth.info.image,
      first_name: auth.info.given_name || auth.info.name.split.first,
      last_name: auth.info.family_name || auth.info.name.split.last,
      password: SecureRandom.hex(16) # Random password for OAuth users
    )
  end

  def ensure_default_categories
    # Check if user has any categories
    return if categories.exists?

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
#  provider             :string          null       no default           index: index_users_on_provider_and_uid
#  uid                  :string          null       no default           index: index_users_on_provider_and_uid
#  avatar_url           :string          null       no default           no index
#
# Indexes:
#  index_users_on_email           (email) unique
#  index_users_on_provider_and_uid (provider, uid) unique
#
