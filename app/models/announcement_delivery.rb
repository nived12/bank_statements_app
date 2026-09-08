# One row per (user, campaign). The unique index on that pair is what makes a
# broadcast safe to re-run; sent_at nil means the row claimed the slot but the
# mail never got enqueued, so it doubles as the retry list.
class AnnouncementDelivery < ApplicationRecord
  belongs_to :user

  validates :campaign, presence: true

  scope :unsent, -> { where(sent_at: nil) }
end
