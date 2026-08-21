# frozen_string_literal: true

# Manual re-application of category rules to already-imported transactions. Nothing
# here belongs in schedule.yml — a rule's category is indistinguishable from one the
# user set by hand afterwards, so applying it has to be a deliberate act.
#
# Preview is the default; APPLY=1 writes. Updating the category re-runs the
# auto-link callback, so a corrected row also lands on its debt or saving.
namespace :category_rules do
  desc "Re-apply category rules to imported transactions (USER_ID=n, APPLY=1 to write)"
  task backfill: :environment do
    apply = ENV["APPLY"] == "1"
    users = ENV["USER_ID"].present? ? User.where(id: ENV["USER_ID"]) : User.joins(:category_rules).distinct

    users.find_each do |user|
      result = CategoryRules::Backfiller.call(user: user, apply: apply)
      changes = result.payload[:changes]
      next if changes.empty?

      puts "\nUser #{user.id} (#{user.email}) — #{changes.size} transaction(s)"
      changes.each do |change|
        from = Category.find_by(id: change[:from_category_id])&.name || "sin categoría"
        to = Category.find_by(id: change[:to_category_id])&.name
        puts format(
          "  %<date>s  %<description>-55.55s  %<from>s → %<to>s",
          date: change[:date], description: change[:description], from: from, to: to
        )
      end
    end

    puts(apply ? "\nApplied." : "\nPreview only — re-run with APPLY=1 to write.")
  end
end
