# frozen_string_literal: true

namespace :playwright do
  desc "Seed deterministic data for Playwright E2E (e2e@example.com)"
  task seed: :environment do
    ENV["PLAYWRIGHT_E2E"] = "1"
    load Rails.root.join("db/seeds/playwright.rb")
  end
end
