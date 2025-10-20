import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="goal-form"
export default class extends Controller {
  static targets = [
    "goalType",
    "targetAmount",
    "startingDebtAmount",
    "debtFields",
    "autoLinkCheckbox",
    "autoLinkFields",
    "trackReverseSavingsHelp",
    "trackReverseDebtHelp"
  ]

  connect() {
    // Initialize on page load
    this.handleGoalTypeChange()

    // Format any existing values with commas
    this.formatExistingValues()

    // Add form submission handler to strip commas
    const form = this.element.closest('form')
    if (form) {
      form.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }

    // Update track reverse help text based on goal type
    this.updateTrackReverseHelpText()
  }

  // Format existing values on page load
  formatExistingValues() {
    if (this.hasTargetAmountTarget && this.targetAmountTarget.value) {
      const value = parseFloat(this.targetAmountTarget.value.replace(/,/g, ''))
      if (!isNaN(value)) {
        this.targetAmountTarget.value = this.formatNumberWithCommas(value.toFixed(2))
      }
    }

    if (this.hasStartingDebtAmountTarget && this.startingDebtAmountTarget.value) {
      const value = parseFloat(this.startingDebtAmountTarget.value.replace(/,/g, ''))
      if (!isNaN(value)) {
        this.startingDebtAmountTarget.value = this.formatNumberWithCommas(value.toFixed(2))
      }
    }
  }

  // Strip commas from all amount fields before form submission
  stripCommasOnSubmit(event) {
    if (this.hasTargetAmountTarget && this.targetAmountTarget.value) {
      this.targetAmountTarget.value = this.targetAmountTarget.value.replace(/,/g, '')
    }

    if (this.hasStartingDebtAmountTarget && this.startingDebtAmountTarget.value) {
      this.startingDebtAmountTarget.value = this.startingDebtAmountTarget.value.replace(/,/g, '')
    }
  }

  // Toggle debt-specific fields based on goal type
  toggleDebtFields() {
    if (!this.hasDebtFieldsTarget) return

    const goalType = this.hasGoalTypeTarget ? this.goalTypeTarget.value : ""

    if (goalType === "debt_payoff") {
      this.debtFieldsTarget.classList.remove("hidden")
    } else {
      this.debtFieldsTarget.classList.add("hidden")
    }
  }

  // Handle goal type change to set default values
  handleGoalTypeChange() {
    if (!this.hasGoalTypeTarget || !this.hasTargetAmountTarget) return

    const goalType = this.goalTypeTarget.value

    // For debt payoff goals, set target_amount to 0.00 if empty
    if (goalType === "debt_payoff") {
      if (!this.targetAmountTarget.value || this.targetAmountTarget.value === "") {
        this.targetAmountTarget.value = "0.00"
      }
    }

    // Update track reverse help text
    this.updateTrackReverseHelpText()
  }

  // Toggle auto-link fields based on checkbox
  toggleAutoLinkFields() {
    if (!this.hasAutoLinkFieldsTarget) return

    const isChecked = this.hasAutoLinkCheckboxTarget && this.autoLinkCheckboxTarget.checked

    if (isChecked) {
      this.autoLinkFieldsTarget.classList.remove("hidden")
    } else {
      this.autoLinkFieldsTarget.classList.add("hidden")
    }
  }

  // Update track reverse help text based on goal type
  updateTrackReverseHelpText() {
    if (!this.hasTrackReverseSavingsHelpTarget || !this.hasTrackReverseDebtHelpTarget) return
    if (!this.hasGoalTypeTarget) return

    const goalType = this.goalTypeTarget.value

    if (goalType === "debt_payoff") {
      this.trackReverseSavingsHelpTarget.classList.add("hidden")
      this.trackReverseDebtHelpTarget.classList.remove("hidden")
    } else {
      this.trackReverseSavingsHelpTarget.classList.remove("hidden")
      this.trackReverseDebtHelpTarget.classList.add("hidden")
    }
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
}
