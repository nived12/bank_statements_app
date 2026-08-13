# Console defaults for this app, loaded by IRB when it starts in the app root
# (so `rails console` picks it up, locally and on Railway).
#
# IRB loads exactly one rc file — the first that exists, checking $HOME/.irbrc
# before this one. A personal ~/.irbrc on the machine silently wins.
#
# ActiveRecord shortens records for display and neither limit is configurable:
# Relation#inspect stops after 10 rows and appends "...", and #inspect cuts every
# string attribute to 50 characters. `full` goes around both.
#
# The pager is left on. It misbehaved over `railway ssh` because the image had no
# `less`, so IRB fell through its PAGE_COMMANDS list to `more` -- hence the
# "--More--" fragments and the screenful of padding. The Dockerfile installs
# `less` now; the fix belonged there, not here.
#
# `railway ssh` still does not forward the window size (`stty size` reports 0 0,
# and Reline falls back to 24x80), so a pager has to guess how tall your terminal
# is. To hand it the real numbers, open the console with:
#
#   railway ssh "stty rows $(tput lines) cols $(tput cols); exec rails c"
#
# The $(...) run on your machine, which is the only side that knows.

if defined?(ActiveRecord::Base)
  # Print every record, with every value at full length.
  #
  #   full User.first.transactions
  #   full Transaction.find(1449)
  #
  # Values run through the same filter #inspect uses -- no more, no less -- so
  # encrypted and password-ish columns still come back [FILTERED] while ordinary
  # fields stay readable. Reusing it means there is no second list to keep in
  # sync: change config.filter_parameters and this follows.
  def full(subject)
    records = subject.is_a?(ActiveRecord::Base) ? [subject] : subject.to_a
    pp records.map { |record| record.class.inspection_filter.filter(record.attributes) }
    nil
  end
end
