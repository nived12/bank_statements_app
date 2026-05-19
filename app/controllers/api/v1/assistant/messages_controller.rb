# frozen_string_literal: true

module Api
  module V1
    module Assistant
      class MessagesController < BaseController
        # GET /api/v1/assistant/conversations/:conversation_id/messages
        def index
          conversation = current_user.assistant_conversations.find(params[:conversation_id])
          @messages = paginate(conversation.messages.order(:created_at))
        rescue ActiveRecord::RecordNotFound
          render_error("CONVERSATION_NOT_FOUND", message: "Conversation not found", status: :not_found)
        end
      end
    end
  end
end
