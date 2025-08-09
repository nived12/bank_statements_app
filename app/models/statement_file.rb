class StatementFile < ApplicationRecord
  belongs_to :bank_account
  has_one_attached :file

  validates :file, presence: true, on: :create
end
