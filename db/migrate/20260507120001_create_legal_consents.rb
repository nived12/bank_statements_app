# frozen_string_literal: true

class CreateLegalConsents < ActiveRecord::Migration[8.0]
  def change
    create_table :legal_consents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :document_type, null: false
      t.string :document_version, null: false
      t.datetime :accepted_at, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :legal_consents, %i[user_id document_type document_version]
  end
end
