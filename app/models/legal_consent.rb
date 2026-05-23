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
#  id                   :integer         not null   no default           no index
#  user_id              :integer         null       no default           index: idx_on_user_id_document_type_document_version_d1b9f2dccf, index_legal_consents_on_user_id
#  document_type        :string          not null   no default           index: idx_on_user_id_document_type_document_version_d1b9f2dccf
#  document_version     :string          not null   no default           index: idx_on_user_id_document_type_document_version_d1b9f2dccf
#  accepted_at          :datetime        not null   no default           no index
#  ip_address           :string          null       no default           no index
#  user_agent           :string          null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  email                :string          not null   no default           no index
#
# Indexes:
#  idx_on_user_id_document_type_document_version_d1b9f2dccf (user_id, document_type, document_version) non-unique
#  index_legal_consents_on_user_id (user_id) non-unique
#
