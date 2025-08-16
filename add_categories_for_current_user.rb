#!/usr/bin/env ruby

# Simple script to add default categories for the current user
# Run this with: ruby add_categories_for_current_user.rb

require_relative 'config/environment'

# Find your user
user = User.find_by(email: "nivedvengilat@example.com")

if user.nil?
  puts "❌ User not found. Please check the email address."
  exit 1
end

puts "👤 Found user: #{user.email}"
puts "📊 Current categories: #{user.categories.count}"

if user.categories.exists?
  puts "⚠️  User already has categories. Do you want to replace them? (y/N): "
  confirmation = STDIN.gets.chomp.downcase

  if confirmation != 'y'
    puts "Operation cancelled."
    exit 0
  end

  puts "🗑️  Deleting existing categories..."
  user.categories.destroy_all
end

puts "✨ Creating default categories..."
CategoryTemplate.create_categories_for_user(user)

puts "✅ Success! Created #{user.categories.count} categories:"
user.categories.where(parent_id: nil).each do |parent|
  puts "  📁 #{parent.name}"
  parent.children.each do |child|
    puts "    └── #{child.name}"
  end
end

puts "\n🎉 Now you can upload statements and get proper categorization!"
puts "💡 The AI will use these categories to intelligently categorize your transactions."
