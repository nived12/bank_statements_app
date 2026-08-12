# Console defaults for this app, loaded by IRB when it starts in the app root
# (so `rails console` picks it up, locally and on Railway).
#
# IRB loads exactly one rc file — the first that exists, checking $HOME/.irbrc
# before this one. A personal ~/.irbrc on the machine silently wins.
#
# Both settings below exist for the remote console (`railway ssh` -> `rails c`):
#
# 1. The pager. IRB pipes long results through `less`. `railway ssh` does not
#    forward the pty window size, so `less` guesses wrong: lines wrap mid-token,
#    fragments of its "--More--" prompt leak into the output, and it pads the
#    screen with blank rows when it exits. There is nothing to scroll back to
#    over SSH anyway, so it only costs.
#
# 2. Truncated output. ActiveRecord shortens records for display and neither
#    limit is configurable: Relation#inspect stops after 10 rows and appends
#    "...", and #inspect cuts every string attribute to 50 characters. `full`
#    goes around both by printing raw attribute hashes.

IRB.conf[:USE_PAGER] = false if defined?(Rails) && Rails.env.production?

if defined?(ActiveRecord::Base)
  # Print every record, with every value at full length.
  #
  #   full User.first.transactions
  #   full Transaction.find(1449)
  #
  # Note this reads attributes directly, so it bypasses the filter that redacts
  # `password`-ish columns in #inspect. Do not paste the output somewhere.
  def full(subject)
    records = subject.is_a?(ActiveRecord::Base) ? [subject] : subject.to_a
    pp records.map(&:attributes)
    nil
  end
end
