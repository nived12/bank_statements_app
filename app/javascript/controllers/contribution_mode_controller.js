import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="contribution-mode"
export default class extends Controller {
  static targets = ["modeSelect", "frequencyField", "amountField", "calculatedInfo"]

  connect() {
    // Initialize visibility on page load
    this.toggle()
  }

  toggle() {
    const mode = this.modeSelectTarget.value

    if (mode === "") {
      // No tracking mode - hide all fields
      this.frequencyFieldTarget.classList.add("hidden")
      this.amountFieldTarget.classList.add("hidden")
      this.calculatedInfoTarget.classList.add("hidden")
    } else if (mode === "fixed") {
      // Fixed mode - show frequency and amount fields
      this.frequencyFieldTarget.classList.remove("hidden")
      this.amountFieldTarget.classList.remove("hidden")
      this.calculatedInfoTarget.classList.add("hidden")
    } else if (mode === "calculated") {
      // Calculated mode - show frequency and info message
      this.frequencyFieldTarget.classList.remove("hidden")
      this.amountFieldTarget.classList.add("hidden")
      this.calculatedInfoTarget.classList.remove("hidden")
    }
  }
}
