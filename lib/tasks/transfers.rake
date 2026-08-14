# frozen_string_literal: true

# One-off maintenance for transfer reconciliation. Both tasks are manual — nothing
# here belongs in schedule.yml.
#
# Why a backfill exists at all: TransferReconciler only shipped 2026-04-09, so every
# statement imported before then was never reconciled, and tracking keys were not
# captured until this change. Until both are applied to existing rows, self-transfers
# keep counting as income *and* expenses on the dashboard.
#
# Statement PDFs are sensitive and are not retained indefinitely — some blobs are
# already gone from storage. A missing file is an expected outcome here, not an
# error: the task reports it and moves on.
module TransfersBackfill
  extend PdfParser::Concerns::TrackingKey
  extend self

  # Fills blank tracking keys on one statement's transactions.
  #
  # Only assigns when the amount maps to exactly one clave and that clave is not
  # already claimed by another row on the same statement, so re-running produces no
  # further changes. A missing key costs nothing — the reconciler falls back to
  # amount+date — whereas a wrong one would pair two unrelated rows as a transfer.
  #
  # @return [Integer] number of keys assigned
  def backfill(statement_file, dry_run:)
    text = statement_text(statement_file)
    return nil if text.nil?

    keys_by_amount = tracking_keys_by_amount(text)
    return 0 if keys_by_amount.empty?

    claimed = statement_file.transactions.where.not(tracking_key: nil).pluck(:tracking_key).to_set
    assigned = 0

    statement_file.transactions.where(tracking_key: nil).find_each do |transaction|
      key = keys_by_amount[transaction.amount.abs]
      next if key.blank? || claimed.include?(key)

      claimed << key
      assigned += 1
      puts "  statement #{statement_file.id} txn ##{transaction.id} #{transaction.amount.to_s("F")} -> #{key}"
      transaction.update_column(:tracking_key, key) unless dry_run
    end

    assigned
  end

  # @return [String, nil] the statement's text layer, or nil when the file is gone
  def statement_text(statement_file)
    return nil unless statement_file.file.attached?

    blob = statement_file.file.blob
    return nil unless blob.service.exist?(blob.key)

    blob.open do |tempfile|
      TextExtractor.extract_text_layer(tempfile.path, password: statement_file.file_password)
    end
  rescue StandardError
    nil
  end
end

namespace :transfers do
  desc "Backfill transactions.tracking_key from stored statement PDFs (DRY_RUN=1 to preview)"
  task backfill_tracking_keys: :environment do
    dry_run = ENV["DRY_RUN"].present?
    statements = unreadable = touched = assigned = errors = 0

    puts dry_run ? "DRY RUN — no changes will be written" : "Backfilling tracking keys"

    User.find_each do |user|
      user.statement_files.includes(file_attachment: :blob).find_each do |statement_file|
        statements += 1
        count = TransfersBackfill.backfill(statement_file, dry_run: dry_run)

        if count.nil?
          unreadable += 1
        elsif count.positive?
          touched += 1
          assigned += count
        end
      rescue StandardError => e
        errors += 1
        warn "  statement #{statement_file.id}: #{e.class} — #{e.message}"
      end
    end

    puts "statements=#{statements} unreadable=#{unreadable} touched=#{touched} " \
         "keys_assigned=#{assigned} errors=#{errors}"
    puts "Re-run without DRY_RUN to apply." if dry_run
  end

  desc "Run TransferReconciler across all history for every user"
  task reconcile_all: :environment do
    users = auto_linked = candidates = failed = 0

    User.find_each do |user|
      result = Transactions::TransferReconciler.call(user)

      if result.success?
        users += 1
        auto_linked += result.payload[:auto_linked]
        candidates += result.payload[:candidates_created]
      else
        failed += 1
        warn "  user #{user.id}: #{result.errors.full_messages.join(", ")}"
      end
    end

    puts "users=#{users} auto_linked=#{auto_linked} candidates=#{candidates} failed=#{failed}"
  end
end
