# frozen_string_literal: true

class AssistantController < ApplicationController
  before_action :require_confirmed_user!
  before_action :require_assistant_access!

  # GET /assistant
  def show
    @compact = params[:layout] == "compact"

    # FAB panel: user has a subscription but is at the AI cap — render the
    # limit-wall template (wrapped in the vittbot_fab_frame turbo-frame so
    # Turbo can swap it in). Full-page /assistant is still handled by
    # require_assistant_access! redirect.
    @at_limit = @compact && !current_user.assistant_access_result[:allowed]
    if @at_limit
      render template: "assistant/compact_frame_limit_wall", layout: false
      return
    end

    @conversations = current_user.assistant_conversations.kept.recent.limit(20)
    @conversation  = resolve_conversation
    @messages      = @conversation.persisted? ? @conversation.messages.order(:created_at) : []
    @usage         = Assistant::UsageMeter.new(current_user).snapshot

    render template: "assistant/compact_frame", layout: false if @compact
  end

  # POST /assistant/messages
  def create_message
    content = params[:content].to_s.strip

    if content.blank?
      @error_message = t("assistant.errors.blank_message")
      respond_to do |format|
        format.turbo_stream { render :message_error, status: :unprocessable_content }
      end
      return
    end

    @conversation = find_or_assign_conversation

    result = ::Assistant::ChatService.call(
      user: current_user,
      message: content,
      conversation: @conversation,
      locale: I18n.locale.to_s,
      suggestion_key: params[:suggestion_key]
    )

    if result.success?
      @payload = result.payload
      respond_to do |format|
        format.turbo_stream
      end
    else
      @error_message = t("assistant.errors.provider")
      respond_to do |format|
        format.turbo_stream { render :message_error, status: :unprocessable_content }
      end
    end
  rescue ::Assistant::QuotaExceeded
    @error_message = t("assistant.errors.quota")
    respond_to do |format|
      format.turbo_stream { render :message_error, status: :payment_required }
    end
  rescue ::Assistant::ProviderError
    @error_message = t("assistant.errors.provider")
    respond_to do |format|
      format.turbo_stream { render :message_error, status: :bad_gateway }
    end
  end

  private

  def require_assistant_access!
    access = current_user.assistant_access_result
    return if access[:allowed]

    # Allow the FAB compact frame through when the user has a subscription but
    # is just at the AI cap — the show action renders the limit-wall partial.
    return if params[:layout] == "compact" && access[:reason] != :subscription_required

    redirect_to pricing_path, alert: t("assistant.errors.subscription")
  end

  def resolve_conversation
    return current_user.assistant_conversations.new if params[:new].present?

    if params[:conversation_id].present?
      existing = current_user.assistant_conversations.kept.find_by(id: params[:conversation_id])
      return existing if existing
    end

    @conversations.first || current_user.assistant_conversations.new
  end

  def find_or_assign_conversation
    return nil unless params[:conversation_id].present?

    current_user.assistant_conversations.kept.find_by(id: params[:conversation_id])
  end
end
