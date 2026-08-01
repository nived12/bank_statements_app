# frozen_string_literal: true

# GenerateRemindersJob - Runs GenerateRemindersService for all users.
#
# NOT scheduled in config/schedule.yml, on purpose: the service persists nothing
# and its mailer calls are commented out, so a scheduled run would compute
# reminders and discard them. Add a cron entry only once those emails are
# enabled — see Reminders::GenerateRemindersService.
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
