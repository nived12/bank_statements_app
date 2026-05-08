# frozen_string_literal: true

class AddLegalConsentToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :terms_accepted_at, :datetime
    add_column :users, :privacy_accepted_at, :datetime
    add_column :users, :legal_version_accepted, :string
  end
end
