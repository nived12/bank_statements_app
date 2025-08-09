class CreateStatementFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :statement_files do |t|
      t.references :bank_account, null: false, foreign_key: true
      t.string :status
      t.datetime :processed_at
      t.jsonb :parsed_json

      t.timestamps
    end
  end
end
