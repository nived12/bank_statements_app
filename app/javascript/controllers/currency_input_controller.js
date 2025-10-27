import { Controller } from "@hotwired/stimulus"

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
      const value = parseFloat(this.element.value.replace(/,/g, ""))
      if (!isNaN(value)) {
        this.element.value = this.formatNumberWithCommas(value.toFixed(2))
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
    let value = this.element.value

    // Only format if there's a value
    if (!value || value === "") {
      return
    }

    // Remove commas for parsing
    value = value.replace(/,/g, "")

    // Parse the value as a float
    const numValue = parseFloat(value)

    // Check if it's a valid number
    if (isNaN(numValue)) {
      this.element.value = ""
      return
    }

    // Format to 2 decimal places with comma separators
    this.element.value = this.formatNumberWithCommas(numValue.toFixed(2))
  }

  // Strip commas before form submission (so server gets raw number)
  stripCommas() {
    if (this.element.value) {
      this.element.value = this.element.value.replace(/,/g, "")
    }
  }

  // Helper method to add comma separators to numbers
  formatNumberWithCommas(value) {
    const parts = value.toString().split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return parts.join(".")
  }
}
