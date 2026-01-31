namespace :statement_cache do
  desc "Clear cached extractions (use when testing new AI models)"
  task clear: :environment do
    count = StatementFile.where.not(file_hash: nil).update_all(file_hash: nil)
    puts "Cleared #{count} cached extractions"
  end

  desc "Clear cache for specific file hash"
  task :clear_hash, [:hash] => :environment do |_t, args|
    if args[:hash].blank?
      puts "Error: Please provide a file hash"
      puts "Usage: rails statement_cache:clear_hash[HASH_VALUE]"
      exit 1
    end

    count = StatementFile.where(file_hash: args[:hash]).update_all(file_hash: nil)
    puts "Cleared #{count} cached extractions for hash #{args[:hash]}"
  end

  desc "Show cache statistics"
  task stats: :environment do
    total = StatementFile.count
    cached = StatementFile.where.not(file_hash: nil).count
    unique_hashes = StatementFile.where.not(file_hash: nil).distinct.count(:file_hash)

    puts "Statement Cache Statistics:"
    puts "  Total statements: #{total}"
    puts "  Cached statements: #{cached}"
    puts "  Unique file hashes: #{unique_hashes}"
    puts "  Cache hit potential: #{((cached.to_f / total) * 100).round(2)}%" if total > 0
  end
end
