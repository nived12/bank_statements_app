import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleButton", "content"]
  static values = { 
    hideText: String,
    showText: String 
  }

  connect() {
    console.log("GoalCalculationSettingsController connected")
    this.isExpanded = false
    this.updateToggleText()
  }

  toggle() {
    console.log("Toggle clicked, current state:", this.isExpanded)
    this.isExpanded = !this.isExpanded
    
    if (this.isExpanded) {
      this.contentTarget.classList.remove("hidden")
      console.log("Content shown")
    } else {
      this.contentTarget.classList.add("hidden")
      console.log("Content hidden")
    }
    
    this.updateToggleText()
  }

  updateToggleText() {
    if (this.isExpanded) {
      this.toggleButtonTarget.textContent = this.hideTextValue || "Hide Advanced Settings"
    } else {
      this.toggleButtonTarget.textContent = this.showTextValue || "Show Advanced Settings"
    }
    console.log("Button text updated to:", this.toggleButtonTarget.textContent)
  }
}
