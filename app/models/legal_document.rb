# frozen_string_literal: true

module LegalDocument
  # Bumping this forces every user to re-consent. Only bump for material
  # LFPDPPP/GDPR changes (new processors, new data categories, expanded
  # retention) — not for clarifications or transparency edits.
  CURRENT_VERSION = "v1.0"
  REQUIRED_DOCUMENTS = %w[terms privacy financial_data].freeze
end
