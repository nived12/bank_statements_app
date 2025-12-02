# Configure Resend API for email delivery
# Get your API key from https://resend.com/api-keys

if ENV["RESEND_API_KEY"].present?
  Resend.api_key = ENV.fetch("RESEND_API_KEY")
end
