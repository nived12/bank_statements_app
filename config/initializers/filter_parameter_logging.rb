# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += %i[
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :account, :accounts, :clabe, :iban, :pan, :card, :number, :last4, :rfc,
  :name, :address, :email, :phone, :amount, :balance,
  :statement_text, :extracted_text, :description, :merchant,
  :parsed_json
]
