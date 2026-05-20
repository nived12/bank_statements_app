# frozen_string_literal: true

module Api
  module V1
    module Assistant
      class ChatsController < BaseController
        # POST /api/v1/assistant/chat
        def create
          message = params[:message].to_s.strip

          if message.blank?
            render_error(
              "VALIDATION_ERROR", message: I18n.t("api.errors.validation_error", default: "Validation failed"),
              status: :unprocessable_content, details: { message: ["can't be blank"] }
            )
            return
          end

          if message.length > 2_000
            render_error(
              "VALIDATION_ERROR", message: I18n.t("api.assistant.message_too_long"),
              status: :unprocessable_content, details: { message: ["is too long (maximum 2000 characters)"] }
            )
            return
          end

          conversation = nil
          if params[:conversation_id].present?
            conversation = current_user.assistant_conversations.find_by(id: params[:conversation_id])
            unless conversation
              render_error(
                "CONVERSATION_NOT_FOUND",
                message: I18n.t("api.assistant.conversation_not_found"),
                status: :not_found
              )
              return
            end
          end

          result = ::Assistant::ChatService.call(
            user: current_user,
            message: message,
            conversation: conversation,
            locale: params[:locale]
          )

          if result.success?
            @result = result.payload
            render :show, status: :ok
          else
            render_error(
              "ASSISTANT_CHAT_FAILED",
              message: I18n.t("api.assistant.chat_failed"),
              status: :unprocessable_content
            )
          end
        rescue ::Assistant::QuotaExceeded => e
          code = e.reason == :ai_limit_reached ? "AI_LIMIT_REACHED" : "ASSISTANT_LIMIT_REACHED"
          render_error(code, message: e.message_text || e.message, status: :payment_required)
        rescue ::Assistant::ProviderError => e
          # Don't leak raw provider exception text to clients — strings can
          # contain API keys, internal hostnames, or stack info. Log server-side
          # and return a stable, localized message.
          Rails.logger.warn("Assistant provider error: #{e.class}: #{e.message}")
          render_error(
            "ASSISTANT_PROVIDER_ERROR",
            message: I18n.t("api.assistant.provider_error"),
            status: :bad_gateway
          )
        end
      end
    end
  end
end
