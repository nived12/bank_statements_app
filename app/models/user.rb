class User < ApplicationRecord
  include FinancialCalculations
  include SubscriptionPlans
  include SubscriptionAccess
  include Discard::Model

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
  has_many :devices, dependent: :destroy
  has_many :recurring_series, dependent: :destroy
  has_many :legal_consents, dependent: :nullify
  has_many :assistant_conversations, dependent: :destroy
  # Messages cascade via the conversation association — no direct User→Message path needed.
  has_one :user_setting, dependent: :destroy
  has_one :quota, class_name: "UserQuota", dependent: :destroy
  # App Store billing lives here the way Stripe billing lives in pay_subscriptions —
  # off the users table, in the model that owns it.
  has_one :apple_premium_subscription, dependent: :destroy
  has_one_attached :avatar_image

  validates :email, presence: true,
    uniqueness: { conditions: -> { kept } },
    format: { with: URI::MailTo::EMAIL_REGEXP }
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

  # Founding-member promise, published on the landing page and in the FAQ: anyone who
  # signs up by 2026-12-31 keeps the Free plan exactly as it is today, permanently.
  # Derived from created_at rather than stamped into its own column — the signup date
  # *is* the evidence, so a separate column would only add a way for the two to drift.
  # Cutoff is the end of 2026-12-31 in Mexico City (UTC-6), the market it was offered in.
  #
  # Deliberately a constant and not an ENV var: this is a published consumer offer, not
  # configuration. Changing it should require a commit and a failing spec, not a quiet
  # dashboard edit.
  #
  # TODO(2027-01): #founding_member? has no callers yet, and that is the whole point —
  # the promise only bites once the Free plan actually gains limits. When those limits
  # are built (account caps, history window), every one of them must check
  # `founding_member?` and exempt pre-cutoff accounts. Until then this is latent by design.
  FOUNDING_MEMBER_CUTOFF = Time.utc(2027, 1, 1, 6).freeze

  after_create :create_default_data
  after_create :create_default_settings
  after_create :create_default_quota

  generates_token_for :email_confirmation, expires_in: 24.hours

  # Deliberately never expires. An unsubscribe link has to keep working in an
  # email the recipient opens a year late — an expired opt-out is not an opt-out.
  generates_token_for :email_unsubscribe

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

  # Check if user has accepted the current legal document version
  def legal_consent_current?
    legal_version_accepted == LegalDocument::CURRENT_VERSION
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
    # Find existing OAuth user (only active accounts — discarded users cannot OAuth-sign-in)
    user = kept.find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # Find existing user by email and link OAuth account
    existing_user = kept.find_by(email: auth.info.email)
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

  # Whether this account is covered by the founding-member promise.
  def founding_member?
    created_at.present? && created_at < FOUNDING_MEMBER_CUTOFF
  end

  private

  def create_default_data
    # Create default categories. Savings/debts/goals are NOT auto-created —
    # users start them from selectable templates (see FinancialTemplate).
    CategoryTemplate.create_categories_for_user(self)
  end

  def create_default_settings
    create_user_setting!
  end

  def create_default_quota
    create_quota!
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
#  email                :string          not null   no default           index: index_users_on_email_active
#  password_digest      :string          null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  provider             :string          null       no default           index: index_users_on_provider_and_uid
#  uid                  :string          null       no default           index: index_users_on_provider_and_uid
#  avatar_url           :string          null       no default           no index
#  confirmed_at         :datetime        null       no default           no index
#  jti                  :string          null       no default           index: index_users_on_jti
#  refresh_token_expires_at :datetime        null       no default           no index
#  trial_ends_at        :datetime        null       no default           index: index_users_on_trial_ends_at_active
#  terms_accepted_at    :datetime        null       no default           no index
#  privacy_accepted_at  :datetime        null       no default           no index
#  legal_version_accepted :string          null       no default           no index
#  discarded_at         :datetime        null       no default           index: index_users_on_discarded_at
#  trial_reminder_stage :integer         null       no default           no index
#
# Indexes:
#  index_users_on_discarded_at    (discarded_at) non-unique
#  index_users_on_email_active    (email) unique
#  index_users_on_jti             (jti) unique
#  index_users_on_provider_and_uid (provider, uid) unique
#  index_users_on_trial_ends_at_active (trial_ends_at) non-unique
#
