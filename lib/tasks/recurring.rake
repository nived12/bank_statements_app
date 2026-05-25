# frozen_string_literal: true

namespace :recurring do
  desc "Run detection for every active user (one-time backfill after Phase 16 deploy)"
  task backfill_detection: :environment do
    total = User.where(confirmed_at: ..Time.current).count
    puts "[recurring:backfill_detection] enqueueing for #{total} users"
    User.where(confirmed_at: ..Time.current).find_each do |user|
      Recurring::DetectForUserJob.perform_later(user.id)
    end
    puts "[recurring:backfill_detection] done"
  end
end
