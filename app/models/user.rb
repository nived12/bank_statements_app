class User < ApplicationRecord
  include FinancialCalculations
  include SubscriptionPlans
  include SubscriptionAccess

  has_secure_password

  pay_customer

  has_many :bank_accounts, dependent: :destroy
  has_many :statement_files, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :goals, dependent: :destroy
  has_many :savings, dependent: :destroy
  has_many :debts, dependent: :destroy
  has_many :category_rules, dependent: :destroy
  has_many :transfer_candidates, dependent: :destroy
  has_one :user_settings, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :password, length: { minimum: 6 }, if: -> { password.present? }
  validates :provider, presence: true, if: -> { provider.present? }
  validates :uid, presence: true, if: -> { provider.present? }
  validates :provider, uniqueness: { scope: :uid }, if: -> { provider.present? && uid.present? }
  validates :avatar_url,
    format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
              message: "must be a valid HTTP or HTTPS URL" },
    allow_blank: true

  after_create :create_default_data
  after_create :create_default_settings

  generates_token_for :email_confirmation, expires_in: 24.hours

  def full_name
    "#{first_name&.strip} #{last_name&.strip}".strip
  end

  def oauth_user?
    provider.present? && uid.present?
  end

  # Determines if user can reset password via email (OAuth users cannot)
  def can_reset_password?
    !oauth_user?
  end

  # Check if user's email has been confirmed
  def confirmed?
    oauth_user? || confirmed_at.present?
  end

  # Confirm user's email
  def confirm_email!
    update!(confirmed_at: Time.current)
  end

  # Send confirmation email
  def send_confirmation_email
    ApplicationMailer.confirmation_email(self).deliver_later
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
        last_name: auth.info.family_name || auth.info.name.split.last,
        confirmed_at: Time.current # OAuth users are auto-confirmed
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
      password: SecureRandom.hex(16), # Random password for OAuth users
      confirmed_at: Time.current # OAuth users are auto-confirmed
    )
  end

  def ensure_default_categories
    # Check if user has any categories
    return if categories.exists?

    create_default_categories
  end

  private

  def create_default_data
    # Create default categories
    CategoryTemplate.create_categories_for_user(self)

    # Create example savings first
    SavingTemplate.create_example_savings_for_user(self)

    # Create example debts
    DebtTemplate.create_example_debts_for_user(self)

    # Create example goals (which will associate with the savings/debts)
    GoalTemplate.create_example_goals_for_user(self)

    Rails.logger.info "Created example financial data for user #{id}"
  end

  def create_default_settings
    create_user_settings!
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
#  confirmed_at         :datetime        null       no default           no index
#  jti                  :string          null       no default           index: index_users_on_jti
#  refresh_token_expires_at :datetime        null       no default           no index
#  trial_ends_at        :datetime        null       no default           no index
#
# Indexes:
#  index_users_on_email           (email) unique
#  index_users_on_jti             (jti) unique
#  index_users_on_provider_and_uid (provider, uid) unique
#
