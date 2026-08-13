# Be sure to restart your server when you modify this file.

# Parameters filtered from the logs, per our privacy terms. Matching is partial,
# so `passw` covers password and password_confirmation. Most of these never
# appear as a database column -- they are here because a request can POST them.
#
# The colons and commas here belong to array literals, not to %i[]. Writing
# %i[:passw, :email] builds the symbols :":passw," and :":email,", which match no
# parameter that has ever existed. This list read as protection while filtering
# nothing at all.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn cvv cvc
  email name address phone rfc
  account accounts clabe iban pan card number last4
  amount balance
  statement_text extracted_text description merchant parsed_json
]

# #inspect reads a separate list, which Rails seeds from the one above. Applied
# wholesale it makes a production console useless: `amount`, `description` and
# `merchant` disappear, `account` takes bank_account_id with it, and `card`
# matches discarded_at.
#
# So the console hides passwords and nothing else. Encrypted columns do not need
# listing -- ActiveRecord::Encryption adds them per model, and the loop below
# preserves those additions.
CONSOLE_FILTERED_ATTRIBUTES = %i[passw].freeze

Rails.application.config.after_initialize do
  ActiveRecord::Base.filter_attributes = CONSOLE_FILTERED_ATTRIBUTES

  # Models that call `encrypts` snapshot filter_attributes when they load. Under
  # eager loading that happens before this runs, so the assignment above would
  # miss them; rebuild theirs from their own encrypted columns.
  ActiveRecord::Base.descendants.each do |model|
    next unless model.instance_variable_get(:@filter_attributes)

    model.filter_attributes = CONSOLE_FILTERED_ATTRIBUTES + model.encrypted_attributes.to_a
  end
end
