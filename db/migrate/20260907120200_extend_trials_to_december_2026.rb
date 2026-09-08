# One-time goodwill extension: every trialling or lapsed account moves to
# 2026-12-31. Announced by content/announcements/trial-extension-2026-12-*.md,
# whose audience is defined as "whoever sits on this date".
#
# Uses the User model rather than raw SQL because paid access spans
# pay_subscriptions and apple_premium_subscriptions. On a fresh database there
# are no users, so this is inert.
class ExtendTrialsToDecember2026 < ActiveRecord::Migration[8.0]
  TARGET = Date.new(2026, 12, 31).end_of_day

  def up
    eligible.each do |user|
      # trial_reminder_stage only ever decreases, so leaving it set would mute
      # every future 7/3/1-day reminder for these users, permanently.
      user.update_columns(trial_ends_at: TARGET, trial_reminder_stage: nil)
    end
  end

  # Irreversible by design: the previous per-user dates are not recorded
  # anywhere, so there is nothing to restore.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def eligible
    User.kept
        .where.not(confirmed_at: nil)
        .where(internal_account: false)
        .includes(:pay_subscriptions, :apple_premium_subscription)
        .reject(&:active_paid_subscription?)
  end
end
