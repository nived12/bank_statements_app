class User < ApplicationRecord
  has_secure_password

  has_many :bank_accounts, dependent: :destroy
  has_many :statement_files, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :categories, dependent: :destroy

  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
