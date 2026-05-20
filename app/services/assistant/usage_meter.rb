# frozen_string_literal: true

module Assistant
  # Enforces the AI Assistant message quota.
  #
  # - Trial users share the existing 15-call `ai_usage_count` pool with voice/image
  #   parsing (no separate counter). Defers entirely to User#ai_access_result.
  # - Paid users have a monthly cap anchored on their subscription anniversary day,
  #   advanced lazily on read via `advance_anchor_if_due!` (no Sidekiq cron).
  class UsageMeter
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Returns { allowed:, reason:, message: }
    # Paid users: checks monthly cap (advances anchor first).
    # Trial users: defers to user.ai_access_result (15-call shared pool).
    def access_result
      if user.active_paid_subscription?
        advance_anchor_if_due!
        ensure_reset_at_initialized!

        if user.assistant_messages_this_month >= SubscriptionAccess.premium_monthly_assistant_messages
          return {
            allowed: false,
            reason: :assistant_limit_reached,
            message: I18n.t(
              "api.assistant.limit_reached",
              limit: SubscriptionAccess.premium_monthly_assistant_messages
            )
          }
        end

        { allowed: true }
      else
        # Trial users (or others) — defer to existing ai_access_result.
        user.ai_access_result
      end
    end

    # Atomically check + increment under a row lock so the gate check and the
    # increment can't race with another request. Raises Assistant::QuotaExceeded
    # if not allowed.
    def consume!
      user.with_lock do
        result = access_result
        unless result[:allowed]
          raise Assistant::QuotaExceeded.new(result[:reason], result[:message])
        end

        if user.active_paid_subscription?
          user.increment!(:assistant_messages_this_month)
        else
          user.increment!(:ai_usage_count)
        end
      end

      true
    end

    # Public view of the current quota state for the `meta.usage` JSON envelope.
    def snapshot
      if user.active_paid_subscription?
        advance_anchor_if_due!
        ensure_reset_at_initialized!
        limit = SubscriptionAccess.premium_monthly_assistant_messages
        used  = user.assistant_messages_this_month.to_i
        base = {
          plan: "premium",
          used: used,
          limit: limit,
          remaining: [limit - used, 0].max,
          resets_at: user.assistant_messages_reset_at&.iso8601
        }
        triggered = next_threshold_crossed(used: used, limit: limit)
        if triggered
          user.update_columns(assistant_threshold_shown: triggered, updated_at: Time.current)
          base[:threshold_crossed] = triggered
        end
        base
      elsif user.active_trial?
        limit = SubscriptionAccess.free_tier_ai_calls
        used  = user.ai_usage_count.to_i
        {
          plan: "trial",
          used: used,
          limit: limit,
          remaining: [limit - used, 0].max,
          resets_at: nil
        }
      else
        {
          plan: nil,
          used: 0,
          limit: 0,
          remaining: 0,
          resets_at: nil
        }
      end
    end

    # Advances `assistant_messages_reset_at` past now, preserving the original
    # anchor day (so a 31st-of-month subscriber resets on the 28/29th in February
    # but returns to the 31st in March).
    # Zeros the counter only on the first advance per call.
    def advance_anchor_if_due!
      reset_at = user.assistant_messages_reset_at
      return if reset_at.nil?
      return if Time.current < reset_at

      anchor_day = user.assistant_anchor_day || reset_at.day
      new_reset_at = next_anchored_reset(reset_at, anchor_day)
      new_reset_at = next_anchored_reset(new_reset_at, anchor_day) while Time.current >= new_reset_at

      user.update_columns(
        assistant_messages_this_month: 0,
        assistant_messages_reset_at: new_reset_at,
        assistant_anchor_day: anchor_day,
        assistant_threshold_shown: 0,
        updated_at: Time.current
      )
    end

    private

    THRESHOLDS = [95, 90, 80].freeze

    def next_threshold_crossed(used:, limit:)
      return nil if limit.to_i <= 0

      pct = (used.to_f / limit) * 100
      shown = user.assistant_threshold_shown.to_i
      THRESHOLDS.find { |t| pct >= t && shown < t }
    end

    # Given a current reset moment and an anchor day-of-month, returns the next
    # reset moment in the following calendar month, clamped to the last day of
    # that month when shorter. Preserves the time-of-day.
    def next_anchored_reset(current, anchor_day)
      base = current + 1.month
      target_month = base.to_date
      last_day = Date.new(target_month.year, target_month.month, -1).day
      effective_day = [anchor_day, last_day].min

      Time.zone.local(
        target_month.year,
        target_month.month,
        effective_day,
        current.hour,
        current.min,
        current.sec
      )
    end

    # If a paid user has never had `assistant_messages_reset_at` set (e.g. they
    # subscribed before this feature shipped), initialize it from their current
    # Pay subscription period or fall back to "now + 1 month". Also captures
    # the anchor day-of-month so future resets preserve it across short months.
    def ensure_reset_at_initialized!
      return if user.assistant_messages_reset_at.present?

      sub = user.current_paid_subscription
      anchor =
        if sub.respond_to?(:current_period_start) && sub.current_period_start.present?
          sub.current_period_start + 1.month
        elsif sub&.created_at.present?
          base = sub.created_at
          base += 1.month while base <= Time.current
          base
        else
          Time.current + 1.month
        end

      user.update_columns(
        assistant_messages_reset_at: anchor,
        assistant_anchor_day: user.assistant_anchor_day || anchor.day,
        updated_at: Time.current
      )
    end
  end
end
