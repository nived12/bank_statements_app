# frozen_string_literal: true

# GenerateRemindersJob - Daily job to generate reminders for debts and savings
# Runs the GenerateRemindersService for all users
class GenerateRemindersJob < ApplicationJob
  queue_as :default

  def perform
    # Generate reminders for all users
    result = Reminders::GenerateRemindersService.call

    if result.success?
      Rails.logger.info("Generated #{result.payload[:debt_payments].size} debt payment reminders")
      Rails.logger.info("Generated #{result.payload[:savings_contributions].size} savings contribution reminders")
    else
      Rails.logger.error("Failed to generate reminders: #{result.errors}")
    end
  end
end
