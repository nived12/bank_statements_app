# frozen_string_literal: true

module Notifications
  class PushJob < ApplicationJob
    queue_as :default

    def perform(user_id:, title:, body:, data: {}, notification_type: nil)
      user = User.find_by(id: user_id)
      return unless user

      if notification_type
        settings = user.user_setting || user.build_user_setting
        return unless settings.public_send(:"notify_#{notification_type}")
      end

      Notifications::PushSender.call(user: user, title: title, body: body, data: data)
    end
  end
end
