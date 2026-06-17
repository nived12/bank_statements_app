# frozen_string_literal: true

module BlogHelper
  MONTHS_ES = %w[enero febrero marzo abril mayo junio julio agosto
                 septiembre octubre noviembre diciembre].freeze

  # "17 de junio de 2026" — avoids depending on the global I18n locale, which
  # the marketing pages don't set.
  def spanish_date(date)
    return "" if date.blank?

    "#{date.day} de #{MONTHS_ES[date.month - 1]} de #{date.year}"
  end
end
