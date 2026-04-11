class BelvoLink < ApplicationRecord
  MAX_LINKS_PER_USER = 3

  belongs_to :user
  belongs_to :bank, optional: true
  has_many :bank_accounts, dependent: :nullify

  encrypts :belvo_link_id, deterministic: true

  enum :status, {
    active: "active",
    inactive: "inactive",
    login_error: "login_error",
    token_required: "token_required"
  }

  enum :sync_status, {
    pending: "pending",
    syncing: "syncing",
    synced: "synced",
    error: "error"
  }, prefix: :sync

  validates :belvo_link_id, presence: true, uniqueness: true
  validates :belvo_institution, presence: true
  validates :user_id, presence: true
  validate :user_within_link_limit, on: :create

  scope :needing_reauth, -> { where(status: [:login_error, :token_required]) }

  private

  def user_within_link_limit
    return unless user

    if user.belvo_links.active.where.not(id: id).count >= MAX_LINKS_PER_USER
      errors.add(:base, :link_limit_reached)
    end
  end
end
