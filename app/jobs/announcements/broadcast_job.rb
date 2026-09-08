# frozen_string_literal: true

module Announcements
  # Sends one announcement (content/announcements/<slug>.md) to the audience its
  # frontmatter declares. Knows nothing about any particular campaign: adding a
  # new one means adding a Markdown file, never editing this class.
  #
  # Safe to re-run. The unique index on announcement_deliveries decides who has
  # already been mailed.
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
      # Claim the slot before sending: at-most-once is the right failure mode
      # for bulk mail.
      delivery = AnnouncementDelivery.create!(user: user, campaign: announcement.slug)

      # deliver_now, not deliver_later: this is already a background job, so
      # enqueuing again would add a second hop and, worse, stamp sent_at on a
      # mail that had only been queued. Sending here means sent_at records that
      # Resend accepted it, and a row still holding sent_at nil is genuinely
      # the retry list.
      AnnouncementMailer.broadcast(user, announcement.slug).deliver_now
      delivery.update!(sent_at: Time.current)
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def recipients(announcement)
      AudienceResolver.call(announcement.audience).payload
    end
  end
end
