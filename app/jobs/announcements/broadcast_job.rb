# frozen_string_literal: true

module Announcements
  # Sends one announcement (content/announcements/<slug>.md) to the audience its
  # frontmatter names. Safe to re-run: the unique index on
  # announcement_deliveries decides who has already been mailed.
  class BroadcastJob < ApplicationJob
    queue_as :default

    # The date db/migrate/*_extend_trials_to_december_2026.rb moved trials to.
    # Matching on it is what identifies the users that migration touched.
    #
    # Compared as a Date, never as a timestamp: Ruby's end_of_day carries
    # nanoseconds (.999999999) and Postgres stores microseconds (.999999000),
    # so == against the stored value is always false and the broadcast would
    # silently reach nobody.
    TRIAL_EXTENSION_DATE = Date.new(2026, 12, 31)

    # Frontmatter `audience:` maps to one of these. Deliberately a fixed list
    # rather than a query language in YAML. Each campaign adds one method.
    AUDIENCES = {
      "all" => :audience_all,
      "trial_extended_2026_12_active" => :audience_trial_extended_active,
      "trial_extended_2026_12_onboarding" => :audience_trial_extended_onboarding
    }.freeze

    def perform(slug)
      announcement = Announcement.find(slug)
      raise ArgumentError, "no announcement for slug #{slug.inspect}" if announcement.nil?

      recipients(announcement).each do |user|
        deliver_to(user, announcement)
      rescue StandardError => e
        Rails.logger.error("[Announcements::BroadcastJob] #{slug} user=#{user.id} #{e.class}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end

    private

    def deliver_to(user, announcement)
      # Claim the slot before sending: at-most-once is the right failure mode for
      # bulk mail, and the row is a visible marker when delivery then fails.
      delivery = AnnouncementDelivery.create!(user: user, campaign: announcement.slug)
      AnnouncementMailer.broadcast(user, announcement.slug).deliver_later
      delivery.update!(sent_at: Time.current)
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def recipients(announcement)
      method = AUDIENCES.fetch(announcement.audience) do
        raise ArgumentError, "unknown audience #{announcement.audience.inspect} in #{announcement.slug}"
      end
      send(method)
    end

    # Never mailed by any campaign: internal fixtures, unconfirmed and discarded
    # accounts, and anyone who used the unsubscribe link. Paid users are not
    # excluded here, a feature announcement is exactly for them.
    #
    # Loads the audience into memory because notify_announcements lives in a
    # jsonb blob and active_paid_subscription? spans two associations. Fine in
    # the hundreds; this needs revisiting well before it is thousands.
    def audience_all
      User.kept
          .where.not(confirmed_at: nil)
          .where(internal_account: false)
          .includes(:user_setting, :pay_subscriptions, :apple_premium_subscription)
          .reject { |user| user.user_setting && !user.user_setting.notify_announcements }
    end

    def audience_trial_extended_active
      trial_extended.select { |user| user.transactions.any? }
    end

    def audience_trial_extended_onboarding
      trial_extended.reject { |user| user.transactions.any? }
    end

    # Whoever the extension migration moved and has not started paying since.
    def trial_extended
      audience_all.select { |user| user.trial_ends_at&.to_date == TRIAL_EXTENSION_DATE }
                  .reject(&:active_paid_subscription?)
    end
  end
end
