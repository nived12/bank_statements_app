# frozen_string_literal: true

module RecurringHelper
  # Renders the "Recurrentes" tab label with an optional detected-count badge.
  # Mirrors the Categorías ⇄ Reglas tab pattern.
  def recurring_tab_label
    count = current_user.recurring_series.detected.count
    label = t("transactions.tabs.recurring")
    return label if count.zero?

    safe_join(
      [
            label,
            content_tag(
              :span, count,
              class: "ml-2 text-xs font-semibold bg-indigo-600 text-white rounded-full px-2 py-0.5"
            )
          ], " "
    )
  end
end
