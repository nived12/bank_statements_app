class BelvoDailySyncJob < ApplicationJob
  queue_as :low

  def perform
    BelvoLink.active.find_each do |link|
      date_from = (link.last_synced_at&.to_date || 30.days.ago.to_date).to_s
      date_to = Date.current.to_s

      BelvoSyncJob.perform_later(link.id, date_from: date_from, date_to: date_to)
    end
  end
end
