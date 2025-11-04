import { Controller } from "@hotwired/stimulus"
import { CurrencyFormatter } from "../utilities/currency_formatter"

// Connects to data-controller="debt-form"
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
      this.isNewRecord = this.checkIfNewRecord()
    }

    // Initialize on page load
    this.formatExistingValues()

    // Add form submission handler to strip commas
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }

    // Check initial changes state
    this.checkChanges()
  }

  checkIfNewRecord() {
    // Check if this is a new record by looking at the form action
    const formAction = this.formTarget.action
    const method = this.formTarget.method?.toLowerCase() || this.formTarget.getAttribute('method')?.toLowerCase()

    // A form is new if it's a POST request (not PATCH/PUT)
    const isPost = method === 'post' || method === 'get'

    // Check if the URL ends with the resource name (no ID)
    const endsWithDebts = formAction.endsWith('/debts')

    return isPost && endsWithDebts
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
  }

  // Handle color changes from color picker
  colorChanged(event) {
    if (this.hasColorInputTarget) {
      this.colorInputTarget.value = event.detail.color
    }
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces(event) {
    const input = event.target
    let value = input.value

    // Remove any non-numeric characters except decimal point and commas
    value = value.replace(/[^0-9.,]/g, "")

    // Remove all commas for processing
    value = CurrencyFormatter.stripCommas(value); // Remove(/,/g, "")

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
    input.value = CurrencyFormatter.formatWithCommas(numValue.toFixed(2))
  }


  // Check if form has changes (for submit button state)
  checkChanges() {
    if (!this.hasFormTarget || !this.hasSubmitButtonTarget) return

    const currentFormData = new FormData(this.formTarget)
    let hasChanges = false
    let isValid = true

    // Check if form is valid (all required fields are filled)
    const requiredFields = this.formTarget.querySelectorAll('[required]')

    requiredFields.forEach(field => {
      // For select fields, check if a valid option is selected
      if (field.tagName === 'SELECT') {
        if (!field.value || field.value === '') {
          isValid = false
        }
      } else {
        // For text/date/number fields, check if they have a value
        if (!field.value || field.value.trim() === '') {
          isValid = false
        }
      }
    })

    // Compare current form data with original to detect changes
    for (let [key, value] of currentFormData.entries()) {
      if (this.originalFormData.get(key) !== value) {
        hasChanges = true
        break
      }
    }

    // Update submit button state
    // For new records: enable if all required fields are valid
    // For existing records: enable if valid AND has changes
    const shouldEnable = isValid && (this.isNewRecord || hasChanges)

    if (shouldEnable) {
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

