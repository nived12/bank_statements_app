# frozen_string_literal: true

json.extract!(user, :id, :email, :first_name, :last_name, :full_name)
json.confirmed(user.confirmed?)
json.avatar_url(user.avatar_url)
json.legal_version_accepted(user.legal_version_accepted)
