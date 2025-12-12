# frozen_string_literal: true

json.extract!(user, :id, :email, :first_name, :last_name, :avatar_url)
json.created_at(user.created_at&.iso8601)
json.updated_at(user.updated_at&.iso8601)
