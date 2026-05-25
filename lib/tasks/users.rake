# frozen_string_literal: true

namespace :users do
  desc "Hard-delete an archived user (LFPDPPP Art. 22 right-to-erasure). " \
       "Usage: rake users:hard_delete[USER_ID] CONFIRM=yes"
  task :hard_delete, [:user_id] => :environment do |_t, args|
    user_id = args[:user_id] || ENV["USER_ID"]

    abort("USER_ID required. Usage: rake users:hard_delete[123] CONFIRM=yes") if user_id.blank?
    abort("CONFIRM=yes required to prevent accidents.") unless ENV["CONFIRM"] == "yes"

    user = User.find_by(id: user_id)
    abort("User #{user_id} not found.") unless user

    unless user.discarded?
      abort("User #{user_id} (#{user.email}) is not archived. Archive first via the UI or `user.discard!`.")
    end

    puts "About to HARD DELETE user #{user.id} (#{user.email})"
    puts "  - Statement files: #{user.statement_files.count}"
    puts "  - Transactions:    #{user.transactions.count}"
    puts "  - Bank accounts:   #{user.bank_accounts.count}"
    puts "  - Conversations:   #{user.assistant_conversations.count}"
    puts "  - Legal consents:  #{user.legal_consents.count} (will be retained per LFPDPPP Art. 14)"
    puts ""

    result = Users::Destroyer.call(user: user)

    if result.success?
      puts "✓ User #{user_id} hard-deleted. Email anonymized to deleted-#{user_id}@vitt.io."
    else
      puts "✗ Deletion failed: #{result.errors.full_messages.join(', ')}"
      exit 1
    end
  end
end
