namespace :belvo do
  desc "Disconnect orphan Belvo links (active links with no bank accounts)"
  task cleanup_orphans: :environment do
    orphans = BelvoLink.where(status: :active).select do |link|
      link.bank_accounts.where.not(belvo_account_id: nil).none?
    end

    if orphans.empty?
      puts "No orphan Belvo links found."
      next
    end

    puts "Found #{orphans.size} orphan link(s):"
    orphans.each do |link|
      puts "  - ID: #{link.id}, Institution: #{link.belvo_institution}, Created: #{link.created_at}"
      result = Belvo::LinkDestroyer.call(belvo_link: link)
      if result.success?
        puts "    ✓ Disconnected"
      else
        puts "    ✗ Failed: #{result.errors}"
      end
    end
  end
end
