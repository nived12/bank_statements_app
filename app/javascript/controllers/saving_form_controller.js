import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="saving-form"
export default class extends Controller {
  static targets = [
    "form",
    "submitButton",
    "iconInput",
    "colorInput"
  ]

  connect() {
    // Store original form data for change detection
    if (this.hasFormTarget) {
      this.originalFormData = new FormData(this.formTarget)
    }

    // Initialize on page load
    this.formatExistingValues()

    // Add form submission handler to strip commas
    const form = this.hasFormTarget ? this.formTarget : this.element.closest('form')
    if (form) {
      form.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }

    // Check initial changes state
    this.checkChanges()
  }

  // Format existing values on page load
  formatExistingValues() {
    // Format amount fields if they exist (now using text inputs with inputmode="decimal")
    const amountFields = this.element.querySelectorAll('input[inputmode="decimal"]')
    amountFields.forEach(field => {
      if (field.value && field.value !== "") {
        const value = parseFloat(field.value.replace(/,/g, ''))
        if (!isNaN(value)) {
          field.value = this.formatNumberWithCommas(value.toFixed(2))
        }
      }
    })
  }

  // Strip commas from all amount fields before form submission
  stripCommasOnSubmit(event) {
    const amountFields = this.element.querySelectorAll('input[inputmode="decimal"]')
    amountFields.forEach(field => {
      if (field.value) {
        field.value = field.value.replace(/,/g, '')
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

    input.value = value
  }

  // Format to always show 2 decimal places with comma separators when user leaves the field
  formatDecimal(event) {
    const input = event.target
    let value = input.value

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
      input.value = ""
      return
    }

    // Format to 2 decimal places with comma separators
    input.value = this.formatNumberWithCommas(numValue.toFixed(2))
  }

  // Helper method to add comma separators to numbers
  formatNumberWithCommas(value) {
    const parts = value.toString().split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return parts.join(".")
  }

  // Check if form has changes (for submit button state)
  checkChanges() {
    if (!this.hasFormTarget || !this.hasSubmitButtonTarget) return

    const currentFormData = new FormData(this.formTarget)
    let hasChanges = false

    // Compare current form data with original
    for (let [key, value] of currentFormData.entries()) {
      if (this.originalFormData.get(key) !== value) {
        hasChanges = true
        break
      }
    }

    // Update submit button state
    if (hasChanges) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("text-slate-400", "cursor-not-allowed")
      this.submitButtonTarget.classList.add("text-green-600", "hover:bg-green-50")
    } else {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("text-slate-400", "cursor-not-allowed")
      this.submitButtonTarget.classList.remove("text-green-600", "hover:bg-green-50")
    }
  }

  // Submit form via header button
  submit(event) {
    event.preventDefault()
    if (!this.submitButtonTarget.disabled && this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }
}

