import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleButton", "content"]
  static values = { 
    hideText: String,
    showText: String 
  }

  connect() {
    this.isExpanded = false
    this.updateToggleText()
  }

  toggle() {
    this.isExpanded = !this.isExpanded
    
    if (this.isExpanded) {
      this.contentTarget.classList.remove("hidden")
    } else {
      this.contentTarget.classList.add("hidden")
    }
    
    this.updateToggleText()
  }

  updateToggleText() {
    if (this.isExpanded) {
      this.toggleButtonTarget.textContent = this.hideTextValue || "Hide Advanced Settings"
    } else {
      this.toggleButtonTarget.textContent = this.showTextValue || "Show Advanced Settings"
    }
  }
}
