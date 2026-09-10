# frozen_string_literal: true

module Announcements
  # Sends one announcement (content/announcements/<slug>.md) to the audience its
  # frontmatter declares. Knows nothing about any particular campaign: adding a
  # new one means adding a Markdown file, never editing this class.
  #
  # Safe to re-run. The unique index on announcement_deliveries decides who has
  # already been mailed; a row still holding sent_at nil is retried.
  class BroadcastJob < ApplicationJob
    queue_as :default

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
      delivery = claim(user, announcement.slug)
      return if delivery.nil?

      # deliver_now, not deliver_later: this is already a background job, so
      # enqueuing again would add a second hop and, worse, stamp sent_at on a
      # mail that had only been queued. Sending here means sent_at records that
      # Resend accepted it.
      AnnouncementMailer.broadcast(user, announcement.slug).deliver_now
      delivery.update!(sent_at: Time.current)
    end

    # Claim the slot before sending: at-most-once is the right failure mode for
    # bulk mail. A row that already has sent_at is a finished delivery, and the
    # unique index is what makes the job re-runnable. A row still holding
    # sent_at nil is a claim whose send did not finish, and re-running is the
    # only thing that retries it.
    #
    # Two BroadcastJobs running concurrently for the same slug could both find
    # the same unsent row and both send. Broadcasts are invoked by hand, one
    # slug at a time, and every fix for that window costs more than the window:
    # with_lock holds a transaction open across an HTTP call to Resend.
    def claim(user, campaign)
      AnnouncementDelivery.create!(user: user, campaign: campaign)
    rescue ActiveRecord::RecordNotUnique
      AnnouncementDelivery.unsent.find_by(user: user, campaign: campaign)
    end

    def recipients(announcement)
      AudienceResolver.call(announcement.audience).payload
    end
  end
end
