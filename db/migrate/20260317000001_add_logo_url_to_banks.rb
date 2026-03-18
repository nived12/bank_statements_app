class AddLogoUrlToBanks < ActiveRecord::Migration[8.0]
  def change
    add_column :banks, :logo_url, :string
  end
end
