import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="goal-form"
export default class extends Controller {
  static targets = [
    "goalType",
    "targetAmount",
    "startingDebtAmount",
    "debtFields"
  ]

  connect() {
    // Initialize on page load
    this.handleGoalTypeChange()
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
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces(event) {
    const input = event.target
    let value = input.value

    // Remove any non-numeric characters except decimal point
    value = value.replace(/[^0-9.]/g, "")

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

  // Format to always show 2 decimal places when user leaves the field
  formatDecimal(event) {
    const input = event.target
    let value = input.value

    // Only format if there's a value
    if (!value || value === "") {
      return
    }

    // Parse the value as a float
    const numValue = parseFloat(value)

    // Check if it's a valid number
    if (isNaN(numValue)) {
      input.value = ""
      return
    }

    // Format to 2 decimal places
    input.value = numValue.toFixed(2)
  }
}
