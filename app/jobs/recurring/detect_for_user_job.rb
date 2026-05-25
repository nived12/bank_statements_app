# frozen_string_literal: true

module Recurring
  class DetectForUserJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      user = User.find_by(id: user_id)
      return unless user

      ::Recurring::Detector.new(user).call
    end
  end
end
