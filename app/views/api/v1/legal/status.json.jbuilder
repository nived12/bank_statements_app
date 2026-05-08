json.data do
  json.consent_current @consent_current
  json.required_version LegalDocument::CURRENT_VERSION
  json.accepted_version @user.legal_version_accepted
  json.terms_accepted_at @user.terms_accepted_at&.iso8601
  json.privacy_accepted_at @user.privacy_accepted_at&.iso8601
end
