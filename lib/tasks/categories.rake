namespace :categories do
  desc "Create default categories for existing users who don't have them"
  task create_for_existing_users: :environment do
    puts "Checking existing users for default categories..."

    User.find_each do |user|
      # Check if user has any categories
      if user.categories.exists?
        puts "User #{user.email} already has categories, skipping..."
        next
      end

      puts "Creating default categories for user #{user.email}..."
      CategoryTemplate.create_categories_for_user(user)
      puts "✅ Created categories for #{user.email}"
    end

    puts "Finished creating categories for existing users!"
  end

  desc "Reset all users' categories to default (WARNING: This will delete all existing categories)"
  task reset_all_users: :environment do
    puts "⚠️  WARNING: This will delete ALL existing categories for ALL users!"
    print "Are you sure you want to continue? Type 'yes' to confirm: "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == "yes"
      User.find_each do |user|
        puts "Resetting categories for user #{user.email}..."

        # First delete subcategories (children)
        subcategories = user.categories.where.not(parent_id: nil)
        if subcategories.exists?
          puts "  - Deleting #{subcategories.count} subcategories..."
          subcategories.destroy_all
        end

        # Then delete parent categories
        parent_categories = user.categories.where(parent_id: nil)
        if parent_categories.exists?
          puts "  - Deleting #{parent_categories.count} parent categories..."
          parent_categories.destroy_all
        end

        # Create new categories
        CategoryTemplate.create_categories_for_user(user)
        puts "✅ Reset categories for #{user.email}"
      end
      puts "Finished resetting all users' categories!"
    else
      puts "Operation cancelled."
    end
  end
end
