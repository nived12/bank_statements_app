# frozen_string_literal: true

module Announcements
  # Turns an announcement's declared audience into the users it should reach.
  #
  # Filters are a fixed, generic vocabulary rather than one method per campaign:
  # a campaign describes itself in frontmatter and nothing here changes when a
  # new one is written. Adding a filter adds a reusable predicate, never
  # campaign-specific logic.
  #
  # Loads candidates into memory because notify_announcements lives in a jsonb
  # blob and active_paid_subscription? spans two associations. Fine in the
  # hundreds; revisit well before it is thousands.
  class AudienceResolver < ApplicationService
    # Method symbols rather than lambdas so a filter can preload once for the
    # whole audience instead of querying per user.
    FILTERS = {
      "trial_ends_on" => :trial_ends_on?,
      "has_transactions" => :has_transactions?,
      "paying" => :paying?
    }.freeze

    def initialize(filters = {})
      super()
      @filters = (filters || {}).transform_keys(&:to_s)
    end

    def call
      reject_unknown_filters!

      success(eligible.select { |user| matches?(user) })
    end

    private

    def reject_unknown_filters!
      unknown = @filters.keys - FILTERS.keys
      return if unknown.empty?

      raise ArgumentError, "unknown audience filter(s): #{unknown.join(", ")}. Known: #{FILTERS.keys.join(", ")}"
    end

    # True for every campaign: internal fixtures, unconfirmed and discarded
    # accounts, and anyone who used the unsubscribe link are never mailed.
    def eligible
      User.kept
          .where.not(confirmed_at: nil)
          .where(internal_account: false)
          .includes(:user_setting, :pay_subscriptions, :apple_premium_subscription)
          .reject { |user| user.user_setting && !user.user_setting.notify_announcements }
    end

    def matches?(user)
      @filters.all? { |name, value| send(FILTERS.fetch(name), user, value) }
    end

    def trial_ends_on?(user, date)
      user.trial_ends_at&.to_date == date
    end

    def has_transactions?(user, wanted)
      user_ids_with_transactions.include?(user.id) == wanted
    end

    def paying?(user, wanted)
      user.active_paid_subscription? == wanted
    end

    # One query for the whole audience. user.transactions.any? per user is an
    # N+1 on top of an already fully loaded candidate set.
    def user_ids_with_transactions
      @user_ids_with_transactions ||= Transaction.distinct.pluck(:user_id).to_set
    end
  end
end
