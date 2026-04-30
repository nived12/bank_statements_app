# frozen_string_literal: true

module Notifications
  class PushJob < ApplicationJob
    queue_as :default

    def perform(user_id:, title:, body:, data: {})
      user = User.find_by(id: user_id)
      return unless user

      Notifications::PushSender.call(user: user, title: title, body: body, data: data)
    end
  end
end
