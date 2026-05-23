# frozen_string_literal: true

module Api
  module V1
    module Assistant
      class ConversationsController < BaseController
        before_action :set_conversation, only: [:show, :destroy]

        # GET /api/v1/assistant/conversations
        def index
          @conversations = paginate(current_user.assistant_conversations.kept.recent)
        end

        # GET /api/v1/assistant/conversations/:id
        def show
          @messages = @conversation.messages.order(:created_at)
          @usage    = ::Assistant::UsageMeter.new(current_user).snapshot
        end

        # DELETE /api/v1/assistant/conversations/:id
        def destroy
          if @conversation.discard
            render json: { data: { message: I18n.t("api.assistant.conversation_deleted") } }, status: :ok
          else
            render_error(
              "DELETE_FAILED",
              message: I18n.t("api.assistant.delete_failed"),
              status: :unprocessable_content
            )
          end
        end

        private

        def set_conversation
          @conversation = current_user.assistant_conversations.kept.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error(
            "CONVERSATION_NOT_FOUND",
            message: I18n.t("api.assistant.conversation_not_found"),
            status: :not_found
          )
        end
      end
    end
  end
end
