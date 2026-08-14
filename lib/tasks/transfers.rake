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
    return text if text.is_a?(Symbol)

    keys_by_amount = extractor.tracking_keys_by_amount(text)
    return 0 if keys_by_amount.empty?

    claimed = statement_file.transactions.where.not(tracking_key: nil).pluck(:tracking_key).to_set
    assigned = 0

    # How many rows on this statement share each absolute amount. A clave is printed
    # under one row, but the text gives us no way to tell which row that was once two
    # share an amount — say a card purchase and a SPEI both for 1,000, where only the
    # SPEI carries a clave. Assigning by iteration order would hand a real transfer's
    # key to the purchase, and the reconciler would then link it as a transfer. Skip.
    rows_per_amount = statement_file.transactions.group("ABS(amount)").count
      .transform_keys { |amount| BigDecimal(amount.to_s) }

    statement_file.transactions.where(tracking_key: nil).find_each do |transaction|
      amount = transaction.amount.abs
      next unless rows_per_amount[amount] == 1

      key = keys_by_amount[amount]
      next if key.blank? || claimed.include?(key)

      claimed << key
      assigned += 1
      puts "  statement #{statement_file.id} txn ##{transaction.id} #{transaction.amount.to_s("F")} -> #{key}"
      transaction.update_column(:tracking_key, key) unless dry_run
    end

    assigned
  end

  # Statements are sensitive and not kept forever, so a gone file is an expected
  # outcome. A storage outage is not — and a blanket rescue made the two look
  # identical in the report, which matters when the operator is told to expect a
  # specific number of missing files. Anything unexpected propagates to the task's
  # per-statement rescue, which names the exception.
  #
  # @return [String] the text layer
  # @return [:missing] no attachment, or the blob is gone from storage
  # @return [:encrypted] password-protected and the password has since been cleared
  def statement_text(statement_file)
    return :missing unless statement_file.file.attached?

    blob = statement_file.file.blob
    return :missing unless blob.service.exist?(blob.key)

    blob.open do |tempfile|
      TextExtractor.extract_text_layer(tempfile.path, password: statement_file.file_password)
    end
  rescue TextExtractor::PasswordRequiredError
    :encrypted
  end

  private

  # Resolved lazily, and this is load-bearing: .rake files are loaded by
  # Rails.application.load_tasks *before* the app is initialised, so autoloading is
  # not available yet. Extending the concern at module-definition time raised
  # NameError on every `rake` invocation — including `db:test:prepare`, which broke
  # CI while the specs still passed (rails_helper boots the app before loading tasks).
  def extractor
    @extractor ||= Object.new.extend(PdfParser::Concerns::TrackingKey)
  end
end

namespace :transfers do
  desc "Backfill transactions.tracking_key from stored statement PDFs (DRY_RUN=1 to preview)"
  task backfill_tracking_keys: :environment do
    dry_run = ENV["DRY_RUN"].present?
    statements = missing = encrypted = touched = assigned = errors = 0

    puts dry_run ? "DRY RUN — no changes will be written" : "Backfilling tracking keys"

    User.find_each do |user|
      user.statement_files.includes(file_attachment: :blob).find_each do |statement_file|
        statements += 1

        case (result = TransfersBackfill.backfill(statement_file, dry_run: dry_run))
        when :missing
          missing += 1
        when :encrypted
          encrypted += 1
          warn "  statement #{statement_file.id}: password-protected, password already cleared"
        else
          next unless result.positive?

          touched += 1
          assigned += result
        end
      rescue StandardError => e
        # Distinct from `missing`: a storage outage must not be mistaken for a file
        # that is legitimately gone, or the operator reads it as expected attrition.
        errors += 1
        warn "  statement #{statement_file.id}: #{e.class} — #{e.message}"
      end
    end

    puts "statements=#{statements} missing=#{missing} encrypted=#{encrypted} " \
         "touched=#{touched} keys_assigned=#{assigned} errors=#{errors}"
    puts "`missing` is expected — statements are not retained forever. `errors` is not." if missing.positive?
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
