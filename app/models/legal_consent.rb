# frozen_string_literal: true

class LegalConsent < ApplicationRecord
  belongs_to :user, optional: true

  validates :email, presence: true
  validates :document_type, presence: true,
    inclusion: { in: LegalDocument::REQUIRED_DOCUMENTS }
  validates :document_version, presence: true
  validates :accepted_at, presence: true
end

# == Schema Information
#
# Table name: legal_consents
#
# Columns:
#  id               :integer  not null
#  user_id          :integer  not null  fk: users
#  document_type    :string   not null
#  document_version :string   not null
#  accepted_at      :datetime not null
#  ip_address       :string
#  user_agent       :string
#  created_at       :datetime not null
#  updated_at       :datetime not null
#
# Indexes:
#  index_legal_consents_on_user_id_and_document_type_and_document_version
#
