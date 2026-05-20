# frozen_string_literal: true

module Assistant
  # Enforces the unified AI quota for all AI-powered features (voice, camera,
  # recurring suggestions, assistant LLM turns). One counter covers everyone:
  # trial users get a one-time pool; premium users get a monthly-resetting budget.
  class UsageMeter
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Returns { allowed:, reason:, message: }
    def access_result
      unless user.active_paid_subscription? || user.active_trial?
        return { allowed: false, reason: :subscription_required }
      end

      if user.active_paid_subscription?
        advance_anchor_if_due!
        ensure_reset_at_initialized!
      end

      limit = cap_for_plan
      used  = user.quota.ai_usage_count

      if limit.positive? && used >= limit
        return {
          allowed: false,
          reason: reason_for_plan,
          message: I18n.t("api.assistant.limit_reached")
        }
      end

      { allowed: true }
    end

    # Atomically check + increment under a quota row lock so the gate check
    # and the increment can't race with another concurrent request.
    # Raises Assistant::QuotaExceeded if not allowed.
    def consume!
      user.quota.with_lock do
        result = access_result
        raise Assistant::QuotaExceeded.new(result[:reason], result[:message]) unless result[:allowed]

        user.quota.increment!(:ai_usage_count)
      end

      true
    end

    # Public view of the current quota state for the `meta.usage` JSON envelope.
    # Returns threshold_crossed when the user just crossed an 80/90/95 boundary.
    def snapshot
      advance_anchor_if_due! if user.active_paid_subscription?
      ensure_reset_at_initialized! if user.active_paid_subscription?

      limit = cap_for_plan
      used  = user.quota.ai_usage_count
      base = {
        plan: plan_label,
        used: used,
        limit: limit,
        remaining: [limit - used, 0].max,
        resets_at: user.quota.ai_usage_reset_at&.iso8601
      }

      triggered = next_threshold_crossed(used: used, limit: limit)
      if triggered
        user.quota.update_columns(ai_usage_threshold_shown: triggered, updated_at: Time.current)
        base[:threshold_crossed] = triggered
      end

      base
    end

    # Advances `ai_usage_reset_at` past now, preserving the original anchor day
    # (so a 31st-of-month subscriber resets on the 28/29th in February but returns
    # to the 31st in March). Zeros the counter only on the first advance per cycle.
    def advance_anchor_if_due!
      reset_at = user.quota.ai_usage_reset_at
      return if reset_at.nil?
      return if Time.current < reset_at

      anchor_day  = user.quota.ai_usage_anchor_day || reset_at.day
      new_reset_at = next_anchored_reset(reset_at, anchor_day)
      new_reset_at = next_anchored_reset(new_reset_at, anchor_day) while Time.current >= new_reset_at

      user.quota.update_columns(
        ai_usage_count: 0,
        ai_usage_reset_at: new_reset_at,
        ai_usage_anchor_day: anchor_day,
        ai_usage_threshold_shown: 0,
        updated_at: Time.current
      )
    end

    private

    THRESHOLDS = [95, 90, 80].freeze

    def cap_for_plan
      if user.active_paid_subscription?
        SubscriptionAccess.premium_monthly_ai_calls
      elsif user.active_trial?
        SubscriptionAccess.free_tier_ai_calls
      else
        0
      end
    end

    def reason_for_plan
      user.active_paid_subscription? ? :assistant_limit_reached : :ai_limit_reached
    end

    def plan_label
      if user.active_paid_subscription? then "premium"
      elsif user.active_trial?          then "trial"
      else                                   nil
      end
    end

    def next_threshold_crossed(used:, limit:)
      return nil if limit.to_i <= 0

      pct    = (used.to_f / limit) * 100
      shown  = user.quota.ai_usage_threshold_shown.to_i
      THRESHOLDS.find { |t| pct >= t && shown < t }
    end

    def next_anchored_reset(current, anchor_day)
      base         = current + 1.month
      target_month = base.to_date
      last_day     = Date.new(target_month.year, target_month.month, -1).day
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

    # If a paid user has never had `ai_usage_reset_at` set (e.g. they subscribed
    # before this feature shipped), initialize it from their Pay subscription period
    # or fall back to now + 1 month. Also captures the anchor day-of-month.
    def ensure_reset_at_initialized!
      return if user.quota.ai_usage_reset_at.present?

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

      user.quota.update_columns(
        ai_usage_reset_at: anchor,
        ai_usage_anchor_day: user.quota.ai_usage_anchor_day || anchor.day,
        updated_at: Time.current
      )
    end
  end
end
