# frozen_string_literal: true

namespace :security do
  desc "Revoke all user sessions (emergency use for security breaches)"
  task revoke_all_sessions: :environment do
    puts "⚠️  WARNING: This will log out ALL users from the platform!"
    puts "This action should only be used in case of a security breach."
    print "Are you sure you want to continue? (yes/no): "

    confirmation = $stdin.gets.chomp

    unless confirmation.downcase == "yes"
      puts "❌ Operation cancelled."
      exit
    end

    puts "\n🔒 Revoking all user sessions..."

    # Count users before
    total_users = User.count
    batch_size = 1000
    processed = 0

    puts "Processing #{total_users} users in batches of #{batch_size}..."

    # Process in batches to avoid locking the entire table
    User.in_batches(of: batch_size) do |batch|
      # Use PostgreSQL's gen_random_uuid() function for efficiency
      batch.update_all(
        "jti = gen_random_uuid()::text, refresh_token_expires_at = NULL"
      )

      processed += batch.size
      puts "  Processed #{processed}/#{total_users} users..."
    end

    puts "✅ Successfully revoked sessions for #{processed} users."
    puts "All users will need to log in again."

    # Log this action
    Rails.logger.warn "[SECURITY] All user sessions revoked at #{Time.current} (#{processed} users affected)"
  end

  desc "Revoke all sessions for a specific user by email"
  task :revoke_user_sessions, [:email] => :environment do |_t, args|
    unless args[:email]
      puts "❌ Please provide a user email: rails security:revoke_user_sessions[user@example.com]"
      exit
    end

    user = User.find_by(email: args[:email])

    unless user
      puts "❌ User not found with email: #{args[:email]}"
      exit
    end

    puts "🔒 Revoking all sessions for user: #{user.email}"

    # Generate new JTI to invalidate all tokens
    user.update!(
      jti: SecureRandom.uuid,
      refresh_token_expires_at: nil
    )

    puts "✅ Successfully revoked all sessions for #{user.email}"

    # Log this action
    Rails.logger.warn "[SECURITY] Sessions revoked for user #{user.id} (#{user.email}) at #{Time.current}"
  end
end
