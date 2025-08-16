namespace :categories do
  desc "Create default categories for existing users who don't have meaningful categories"
  task create_for_existing_users: :environment do
    users_needing_categories = []

    User.find_each do |user|
      meaningful_categories = user.categories.where.not(name: "Uncategorized")
      if meaningful_categories.empty?
        users_needing_categories << user
      end
    end

    if users_needing_categories.empty?
      puts "All users already have meaningful categories!"
      next
    end

    puts "Creating default categories for #{users_needing_categories.count} users..."

    users_needing_categories.each do |user|
      puts "  Creating categories for #{user.email}..."
      # Remove the "Uncategorized" category first
      user.categories.where(name: "Uncategorized").destroy_all
      CategoryTemplate.create_categories_for_user(user)
      puts "    Created #{user.categories.count} categories"
    end

    puts "✅ Default categories created for all users!"
  end

  desc "Reset all users to default categories (WARNING: This will delete existing categories)"
  task reset_all_users: :environment do
    print "⚠️  WARNING: This will delete ALL existing categories for ALL users. Continue? (y/N): "
    confirmation = STDIN.gets.chomp.downcase

    if confirmation != "y"
      puts "Operation cancelled."
      return
    end

    User.find_each do |user|
      puts "Resetting categories for #{user.email}..."
      user.categories.destroy_all
      CategoryTemplate.create_categories_for_user(user)
      puts "  Created #{user.categories.count} default categories"
    end

    puts "✅ All users reset to default categories!"
  end
end
