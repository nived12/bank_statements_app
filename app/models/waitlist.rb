class Waitlist < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :locale, presence: true,
    inclusion: { in: I18n.available_locales.map(&:to_s) }
end

# == Schema Information
#
# Table name: waitlists
#
# Columns:
#  id                   :integer         not null   no default           no index
#  email                :string          not null   no default           index: index_waitlists_on_email
#  locale               :string          not null   default: es          no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_waitlists_on_email       (email) unique
#
