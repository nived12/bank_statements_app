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

    def initialize(user:, message:, conversation: nil, conversation_id: nil, locale: nil)
      super()
      @user = user
      @message = message.to_s.strip
      @conversation = conversation
      @conversation_id = conversation_id
      @locale = locale.presence || "es-MX"
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
      decision = Assistant::IntentRouter.new(message: @message, user: @user, context: context).call

      # Stamp the intent on the user message so history-filtering in
      # PromptBuilder can drop both sides of an off-topic / conversational
      # turn from the LLM context.
      user_msg.update_column(:intent, decision[:intent].to_s)

      rendered = render_response(decision, conv, context)

      assistant_msg = persist_assistant_message!(
        conv,
        rendered: rendered,
        decision: decision
      )

      disclaimer = inject_disclaimer!(conv)
      conv.touch_last_message!

      log_event!(decision: decision, rendered: rendered, assistant_msg: assistant_msg)

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

    def find_or_create_conversation!
      return @conversation if @conversation&.persisted? && @conversation.user_id == @user.id

      if @conversation_id.present?
        existing = @user.assistant_conversations.find_by(id: @conversation_id)
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
      prompt = Assistant::PromptBuilder.new(
        user: @user,
        conversation: conversation,
        context: context,
        current_message: @message,
        locale: normalized_locale
      ).call

      provider = ENV["AI_PROVIDER"].presence || "gemini"
      model    = ENV["AI_MODEL"].presence || default_model_for(provider)

      Assistant::UsageMeter.new(@user).consume!

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        response = Ai::Client.new(provider: provider, model: model).chat(prompt)
      rescue => e
        Rails.logger.error("Assistant::ChatService LLM error: #{e.class}: #{e.message}")
        raise Assistant::ProviderError, e.message
      end

      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      prompt_tokens     = response.dig(:usage, :prompt_token_count).to_i
      completion_tokens = response.dig(:usage, :candidates_token_count).to_i
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
        cost_usd: cost_usd
      }
    end

    def persist_assistant_message!(conversation, rendered:, decision:)
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
        next_best_action: rendered[:next_best_action] || {}
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

    def default_model_for(provider)
      provider == "openai" ? "gpt-4o-mini" : "gemini-3-flash-preview"
    end
  end
end
