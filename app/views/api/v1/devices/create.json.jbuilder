json.data do
  json.id @device.id
  json.push_token @device.push_token
  json.platform @device.platform
  json.active @device.active
  json.created_at @device.created_at.iso8601
end
