import { Controller } from "@hotwired/stimulus"
import { CurrencyFormatter } from "../utilities/currency_formatter"

// Connects to data-controller="currency-input"
// Formats currency inputs as $x,xxx.xx for display
// Strips commas on form submission for server processing
export default class extends Controller {
  connect() {
    // Format existing value on page load
    this.formatExistingValue()

    // Add event listeners
    this.element.addEventListener("blur", () => this.formatCurrency())
    this.element.addEventListener("input", () => this.enforceDecimalPlaces())

    // Add form submission handler to strip commas
    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("submit", () => this.stripCommas())
    }
  }

  // Format existing value on page load
  formatExistingValue() {
    if (this.element.value && this.element.value !== "") {
      const value = parseFloat(CurrencyFormatter.stripCommas(this.element.value))
      if (!isNaN(value)) {
        this.element.value = CurrencyFormatter.formatWithCommas(value.toFixed(2))
      }
    }
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces() {
    let value = this.element.value

    // Remove any non-numeric characters except decimal point and commas
    value = value.replace(/[^0-9.,]/g, "")

    // Remove all commas for processing
    value = value.replace(/,/g, "")

    // Only allow one decimal point
    const parts = value.split(".")
    if (parts.length > 2) {
      value = parts[0] + "." + parts.slice(1).join("")
    }

    // Limit to 2 decimal places
    if (parts.length === 2 && parts[1].length > 2) {
      value = parts[0] + "." + parts[1].substring(0, 2)
    }

    this.element.value = value
  }

  // Format to always show 2 decimal places with comma separators when user leaves the field
  formatCurrency() {
    const formatted = CurrencyFormatter.formatCurrency(this.element.value)
    this.element.value = formatted
  }

  // Strip commas before form submission (so server gets raw number)
  stripCommas() {
    if (this.element.value) {
      this.element.value = CurrencyFormatter.stripCommas(this.element.value)
    }
  }
}
