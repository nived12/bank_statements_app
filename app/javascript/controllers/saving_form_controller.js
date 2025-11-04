import BaseFormController from "./base_form_controller"
import { CurrencyFormatter } from "../utilities/currency_formatter"

/**
 * Saving form controller.
 * Extends BaseFormController with currency formatting functionality.
 */
export default class extends BaseFormController {
  static targets = [
    "form",
    "submitButton",
    "iconInput",
    "colorInput"
  ]

  connect() {
    // Call parent connect to set up form validation
    super.connect()

    // Initialize currency formatting on page load
    this.formatExistingValues()

    // Add form submission handler to strip commas
    const form = this.hasFormTarget ? this.formTarget : this.element.closest('form')
    if (form) {
      form.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }
  }

  /**
   * Returns the resource path for savings.
   * @returns {string} The resource path
   */
  getResourcePath() {
    return '/savings'
  }

  // Format existing values on page load
  formatExistingValues() {
    // Format amount fields if they exist (now using text inputs with inputmode="decimal")
    const amountFields = this.element.querySelectorAll('input[inputmode="decimal"]')
    amountFields.forEach(field => {
      if (field.value && field.value !== "") {
        const value = parseFloat(CurrencyFormatter.stripCommas(field.value))
        if (!isNaN(value)) {
          field.value = CurrencyFormatter.formatWithCommas(value.toFixed(2))
        }
      }
    })
  }

  // Strip commas from all amount fields before form submission
  stripCommasOnSubmit(event) {
    const amountFields = this.element.querySelectorAll('input[inputmode="decimal"]')
    amountFields.forEach(field => {
      if (field.value) {
        field.value = CurrencyFormatter.stripCommas(field.value)
      }
    })
  }

  // Handle icon changes from icon picker
  iconChanged(event) {
    if (this.hasIconInputTarget) {
      this.iconInputTarget.value = event.detail.icon
    }
    this.checkChanges()
  }

  // Handle color changes from color picker
  colorChanged(event) {
    if (this.hasColorInputTarget) {
      this.colorInputTarget.value = event.detail.color
    }
    this.checkChanges()
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces(event) {
    const input = event.target
    let value = input.value

    // Remove any non-numeric characters except decimal point and commas
    value = value.replace(/[^0-9.,]/g, "")

    // Remove all commas for processing
    value = CurrencyFormatter.stripCommas(value)

    // Only allow one decimal point
    const parts = value.split(".")
    if (parts.length > 2) {
      value = parts[0] + "." + parts.slice(1).join("")
    }

    // Limit to 2 decimal places
    if (parts.length === 2 && parts[1].length > 2) {
      value = parts[0] + "." + parts[1].substring(0, 2)
    }

    input.value = value
  }

  // Format to always show 2 decimal places with comma separators when user leaves the field
  formatDecimal(event) {
    const input = event.target
    const formatted = CurrencyFormatter.formatCurrency(input.value)
    input.value = formatted
  }

  // Note: checkChanges() and submit() are inherited from BaseFormController
}

