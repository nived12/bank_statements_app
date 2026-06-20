# frozen_string_literal: true

# Read-only catalog of starter templates the user can choose to pre-fill a new
# savings or debt form. These are NOT persisted and never auto-created — they
# only seed the create form so the user enters their own real numbers.
#
# Names/descriptions are i18n keys (resolved at render time). Monetary balances
# are personal and are intentionally omitted; only structural defaults
# (icon/color/calculation settings, and a suggested target/rate) are provided.
class FinancialTemplate
  DEFAULT_SAVING_CALCULATION = {
    income: "positive",
    expense: "negative",
    transfer_in: "positive",
    transfer_out: "negative"
  }.freeze

  DEFAULT_DEBT_CALCULATION = {
    income: "positive",
    expense: "negative",
    transfer_in: "positive",
    transfer_out: "ignore"
  }.freeze

  SAVINGS = [
    {
      key: "emergency_fund",
      icon: "shield",
      color: "#10B981",
      suggested_target_amount: 10_000.00,
      calculation_settings: DEFAULT_SAVING_CALCULATION,
      category_name: "Fondo de Emergencia"
    },
    {
      key: "vacation_fund",
      icon: "plane",
      color: "#3B82F6",
      suggested_target_amount: 5_000.00,
      calculation_settings: DEFAULT_SAVING_CALCULATION,
      category_name: "Fondo de Vacaciones"
    },
    {
      key: "home_down_payment",
      icon: "home",
      color: "#8B5CF6",
      suggested_target_amount: 100_000.00,
      calculation_settings: DEFAULT_SAVING_CALCULATION,
      category_name: "Cuenta de Ahorros"
    },
    {
      key: "new_car",
      icon: "car",
      color: "#F59E0B",
      suggested_target_amount: 50_000.00,
      calculation_settings: DEFAULT_SAVING_CALCULATION,
      category_name: "Cuenta de Ahorros"
    }
  ].freeze

  DEBTS = [
    {
      key: "credit_card",
      icon: "credit-card",
      color: "#EF4444",
      suggested_interest_rate: 18.5,
      calculation_settings: DEFAULT_DEBT_CALCULATION,
      category_name: "Tarjetas de Crédito"
    },
    {
      key: "car_loan",
      icon: "car",
      color: "#F97316",
      suggested_interest_rate: 4.5,
      calculation_settings: DEFAULT_DEBT_CALCULATION,
      category_name: "Crédito Automotriz"
    },
    {
      key: "personal_loan",
      icon: "banknote",
      color: "#EC4899",
      suggested_interest_rate: 12.0,
      calculation_settings: DEFAULT_DEBT_CALCULATION,
      category_name: "Préstamos Personales"
    },
    {
      key: "student_loan",
      icon: "graduation-cap",
      color: "#14B8A6",
      suggested_interest_rate: 7.0,
      calculation_settings: DEFAULT_DEBT_CALCULATION,
      category_name: "Préstamo Estudiantil"
    }
  ].freeze

  class << self
    def for_type(type)
      case type.to_s
      when "saving", "savings" then SAVINGS
      when "debt", "debts" then DEBTS
      end
    end

    # Look up a single template by type + key. Returns the raw hash or nil.
    def find(type, key)
      for_type(type)&.find { |template| template[:key] == key.to_s }
    end

    # Localized display name for a template, e.g. "Fondo de Emergencia".
    def name_for(type, key)
      I18n.t("templates.#{type_namespace(type)}.#{key}.name", default: key.to_s.titleize)
    end

    def description_for(type, key)
      I18n.t("templates.#{type_namespace(type)}.#{key}.description", default: "")
    end

    def type_namespace(type)
      type.to_s == "debt" || type.to_s == "debts" ? "debts" : "savings"
    end
  end
end
