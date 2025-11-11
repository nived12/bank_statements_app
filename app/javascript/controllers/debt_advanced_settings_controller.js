import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="debt-advanced-settings"
export default class extends Controller {
  static targets = ["toggleButton", "content"]

  connect() {
    // Initialize button text
    this.updateButtonText()
  }

  toggle() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden")
      this.updateButtonText()
    }
  }

  updateButtonText() {
    if (this.hasToggleButtonTarget && this.hasContentTarget) {
      const isHidden = this.contentTarget.classList.contains("hidden")
      const hideText = this.data.get("hideTextValue") || "Hide Advanced Settings"
      const showText = this.data.get("showTextValue") || "Show Advanced Settings"

      this.toggleButtonTarget.textContent = isHidden ? showText : hideText
    }
  }
}
