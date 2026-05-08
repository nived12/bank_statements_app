json.data do
  json.consent_accepted true
  json.version @version
  json.accepted_at @accepted_at.iso8601
end
json.message I18n.t("api.legal.consent_recorded")
