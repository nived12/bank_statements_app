# frozen_string_literal: true

module Assistant
  # Orchestrates a single chat turn end-to-end.
  #
  # Flow:
  #   1. Lock the user row + consume quota (UsageMeter)
  #   2. Find-or-create the conversation
  #   3. Persist user message
  #   4. Assemble context
  #   5. Route via IntentRouter
  #   6. Either DeterministicResponder OR Ai::Client.new.chat(prompt)
  #   7. Persist assistant message with telemetry
  #   8. Inject disclaimer if first turn in conversation
  #   9. Return Result struct
  #
  # Errors raised:
  #   - Assistant::QuotaExceeded
  #   - Assistant::ProviderError
  class ChatService < ApplicationService
    Result = Struct.new(
      :conversation,
      :user_message,
      :assistant_message,
      :disclaimer,
      :usage,
      keyword_init: true
    )

    def initialize(user:, message:, conversation: nil, conversation_id: nil, locale: nil, suggestion_key: nil)
      super()
      @user = user
      @message = message.to_s.strip
      @conversation = conversation
      @conversation_id = conversation_id
      @locale = locale.presence || "es-MX"
      @suggestion_key = suggestion_key.presence
    end

    def call
      validate!

      # Pre-flight quota gate (no increment yet). Bails immediately so we
      # don't persist a user message we'll never reply to.
      gate = Assistant::UsageMeter.new(@user).access_result
      unless gate[:allowed]
        raise Assistant::QuotaExceeded.new(gate[:reason], gate[:message])
      end

      # NOTE: no outer transaction wraps the rest of this method. If the LLM
      # provider errors out below, the user's typed message + conversation
      # MUST survive in history. UsageMeter#consume! takes its own row lock
      # so the gate check + increment stay atomic for the LLM path.
      # Deterministic intents intentionally skip consume! — they cost $0 to
      # serve, so the counter stays untouched.
      conv = find_or_create_conversation!
      user_msg = persist_user_message!(conv)

      context = assemble_context

      # Whitelist-gated shortcut — bypasses IntentRouter entirely.
      if valid_suggestion_key?
        rendered = render_suggestion_response
        decision = { intent: :"suggestion_#{@suggestion_key}", path: :deterministic, slots: {} }
        user_msg.update_column(:intent, decision[:intent].to_s)
      else
        decision = Assistant::IntentRouter.new(message: @message, user: @user, context: context).call

        # Stamp the intent on the user message so history-filtering in
        # PromptBuilder can drop both sides of an off-topic / conversational
        # turn from the LLM context.
        user_msg.update_column(:intent, decision[:intent].to_s)

        rendered = render_response(decision, conv, context)
      end

      assistant_msg = persist_assistant_message!(
        conv,
        rendered: rendered,
        decision: decision,
        tools_called: rendered[:tools_called]
      )

      Assistant::SubjectTracker.new(
        conversation: conv,
        intent: decision[:intent],
        tools_called: rendered[:tools_called] || [],
        slots: decision[:slots] || {},
        suggestion_key: @suggestion_key
      ).call

      disclaimer = inject_disclaimer!(conv)
      conv.touch_last_message!

      log_event!(decision: decision, rendered: rendered, assistant_msg: assistant_msg)
      Analytics.capture(distinct_id: @user.id, event: "assistant_message_sent")

      apply_thinking_delay!(rendered)

      result = Result.new(
        conversation: conv,
        user_message: user_msg,
        assistant_message: assistant_msg,
        disclaimer: disclaimer,
        usage: Assistant::UsageMeter.new(@user).snapshot
      )

      success(result)
    end

    private

    def validate!
      raise ArgumentError, "user required" if @user.nil?
      raise ArgumentError, "message blank" if @message.blank?
      raise ArgumentError, "message too long" if @message.length > 2_000
    end

    def valid_suggestion_key?
      @suggestion_key.present? && Assistant::SuggestionResponder::KEYS.include?(@suggestion_key)
    end

    def render_suggestion_response
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      responder = Assistant::SuggestionResponder.new(
        user: @user,
        key: @suggestion_key,
        locale: normalized_locale
      )
      rendered = responder.call
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      {
        text: rendered.text,
        next_best_action: rendered.next_best_action,
        source: :deterministic,
        provider: "internal",
        model: "suggestion-v1",
        prompt_tokens: 0,
        completion_tokens: 0,
        latency_ms: latency_ms,
        cost_usd: 0.0,
        tools_called: []
      }
    end

    def find_or_create_conversation!
      return @conversation if @conversation&.persisted? && @conversation.user_id == @user.id

      if @conversation_id.present?
        existing = @user.assistant_conversations.kept.find_by(id: @conversation_id)
        return existing if existing
      end

      @user.assistant_conversations.create!(
        locale: normalized_locale,
        title: derive_title(@message)
      )
    end

    def persist_user_message!(conversation)
      conversation.messages.create!(
        user: @user,
        role: "user",
        content: @message
      )
    end

    def assemble_context
      Assistant::ContextAssembler.call(user: @user).payload || {}
    end

    def render_response(decision, conversation, context)
      if decision[:path] == :deterministic
        responder = Assistant::DeterministicResponder.new(
          user: @user,
          intent: decision[:intent],
          slots: decision[:slots],
          context: context,
          locale: normalized_locale
        )
        rendered = responder.call
        {
          text: rendered.text,
          next_best_action: rendered.next_best_action,
          source: :deterministic,
          provider: "internal",
          model: "intent-router-v1",
          prompt_tokens: 0,
          completion_tokens: 0,
          latency_ms: 0,
          cost_usd: 0.0
        }
      else
        call_llm(decision, conversation, context)
      end
    end

    def call_llm(decision, conversation, context)
      coaching_data = prefetch_coaching_data_for(decision)

      prompt = Assistant::PromptBuilder.new(
        user: @user,
        conversation: conversation,
        context: context,
        current_message: @message,
        locale: normalized_locale,
        coaching_data: coaching_data
      ).call

      provider = ENV["AI_PROVIDER"].presence || "gemini"
      mode     = decision[:intent] == :llm_freeform ? :pro : :default

      Assistant::UsageMeter.new(@user).consume!

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        client   = Ai::Client.new(provider: provider, mode: mode)
        model    = client.model
        user_ref = @user

        # Use tool-calling loop for Gemini; fall back to plain chat for others.
        response = if provider.downcase == "gemini"
          client.chat_with_tools(
            prompt,
            tools_schema: Assistant::Tools::Registry.declarations,
            on_tool_call: ->(name, args) { Assistant::Tools::Registry.dispatch(name, user: user_ref, **args) }
          )
        else
          client.chat(prompt)
        end
      rescue => e
        Rails.logger.error("Assistant::ChatService LLM error: #{e.class}: #{e.message}")
        raise Assistant::ProviderError, e.message
      end

      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      prompt_tokens     = response.dig(:usage, :prompt_token_count).to_i
      completion_tokens = response.dig(:usage, :candidates_token_count).to_i
      llm_tools         = response[:tools_called] || []
      tools_called      = prefetched_tool_entries(coaching_data) + llm_tools
      cost_usd = Assistant::CostCalculator.call(
        provider: provider,
        model: model,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens
      )

      text = response[:text].to_s.strip
      text = I18n.t("assistant.responses.fallback", locale: i18n_locale) if text.blank?

      {
        text: text,
        next_best_action: infer_next_action_for_llm(decision, context),
        source: :llm,
        provider: provider,
        model: model,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        latency_ms: latency_ms,
        cost_usd: cost_usd,
        tools_called: tools_called
      }
    end

    def persist_assistant_message!(conversation, rendered:, decision:, tools_called: nil)
      conversation.messages.create!(
        user: @user,
        role: "assistant",
        content: rendered[:text],
        intent: decision[:intent].to_s,
        is_deterministic: rendered[:source] == :deterministic,
        prompt_tokens: rendered[:prompt_tokens],
        completion_tokens: rendered[:completion_tokens],
        latency_ms: rendered[:latency_ms],
        cost_usd: rendered[:cost_usd],
        provider: rendered[:provider],
        model: rendered[:model],
        context_snapshot: {},
        next_best_action: rendered[:next_best_action] || {},
        tools_called: tools_called.presence || []
      )
    end

    def inject_disclaimer!(conversation)
      return nil if conversation.disclaimer_shown

      disclaimer = I18n.t("assistant.disclaimer", locale: i18n_locale)
      conversation.update_column(:disclaimer_shown, true)
      disclaimer
    end

    def log_event!(decision:, rendered:, assistant_msg:)
      Rails.logger.info(
        {
          event: "assistant.chat",
          user_id: @user.id,
          conversation_id: assistant_msg.assistant_conversation_id,
          intent: decision[:intent],
          path: rendered[:source] == :deterministic ? "det" : "llm",
          provider: rendered[:provider],
          model: rendered[:model],
          prompt_tokens: rendered[:prompt_tokens],
          completion_tokens: rendered[:completion_tokens],
          latency_ms: rendered[:latency_ms],
          cost_usd: rendered[:cost_usd]
        }.to_json
      )
    end

    def infer_next_action_for_llm(decision, _context)
      case decision[:intent]
      when :debt_payoff      then { kind: "open_screen", screen: "finances" }
      when :goal_progress    then { kind: "open_screen", screen: "finances" }
      when :account_balance  then { kind: "open_screen", screen: "accounts" }
      else nil
      end
    end

    def derive_title(message)
      message.gsub(/\s+/, " ").strip[0, 80]
    end

    # Public-facing locale label (preserved for API responses + downstream services).
    def normalized_locale
      @locale.to_s.start_with?("en") ? "en" : "es-MX"
    end

    # Locale symbol for I18n.t calls. The Rails I18n stack uses :en and :es;
    # the conversation locale "es-MX" maps to :es.
    def i18n_locale
      @locale.to_s.start_with?("en") ? :en : :es
    end

    def prefetch_coaching_data_for(decision)
      return nil unless decision[:intent] == :llm_freeform

      today        = Date.current
      month_start  = today.beginning_of_month
      month_end    = today.end_of_month

      transactions = safe_tool do
        Assistant::Tools::QueryTransactions.new(
          user: @user, date_from: month_start.iso8601, date_to: month_end.iso8601, limit: 50
        ).call
      end

      summary = safe_tool do
        Assistant::Tools::GetPeriodSummary.new(
          user: @user, period: "this_month"
        ).call
      end

      recurring = safe_tool do
        Assistant::Tools::GetRecurringPayments.new(
          user: @user, lookback_days: 90
        ).call
      end

      {
        period: month_start.strftime("%Y-%m"),
        period_summary: summary,
        recent_transactions: transactions,
        recurring_payments: recurring
      }
    rescue => e
      Rails.logger.warn("Assistant::ChatService coaching prefetch failed: #{e.class}: #{e.message}")
      nil
    end

    def safe_tool
      yield
    rescue => e
      Rails.logger.warn("Assistant::ChatService prefetched tool failed: #{e.class}: #{e.message}")
      { error: e.message }
    end

    def prefetched_tool_entries(coaching_data)
      return [] if coaching_data.blank?

      period = coaching_data[:period]
      [
        { "name" => "query_transactions", "args" => { "date_from" => Date.current.beginning_of_month.iso8601,
                                                        "date_to" => Date.current.end_of_month.iso8601,
                                                        "limit" => 50 },
          "prefetched" => true },
        { "name" => "get_period_summary", "args" => { "period" => "this_month" }, "prefetched" => true },
        { "name" => "get_recurring_payments", "args" => { "lookback_days" => 90 }, "prefetched" => true }
      ].tap { |_| _ }.tap { |_| @prefetched_period = period }
    end

    THINKING_DELAY_RANGE_DEFAULT = (0.6..1.1).freeze

    def apply_thinking_delay!(rendered)
      return if rendered[:source] != :deterministic
      return if Rails.env.test?

      range = thinking_delay_range
      sleep(rand(range))
    end

    def thinking_delay_range
      raw = ENV["ASSISTANT_THINKING_DELAY_MS"].to_s
      if raw.match?(/\A\d+\s*,\s*\d+\z/)
        lo, hi = raw.split(",").map { |v| v.to_i / 1000.0 }
        return (lo..hi) if lo > 0 && hi >= lo
      end
      THINKING_DELAY_RANGE_DEFAULT
    end
  end
end
