import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-link-toggle"
export default class extends Controller {
  static targets = ["checkbox", "categoryLabel", "bankAccountLabel"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isChecked = this.checkboxTarget.checked

    // Toggle required state for labels
    if (this.hasCategoryLabelTarget) {
      this.updateLabel(this.categoryLabelTarget, isChecked)
    }

    if (this.hasBankAccountLabelTarget) {
      this.updateLabel(this.bankAccountLabelTarget, isChecked)
    }
  }

  updateLabel(labelElement, isRequired) {
    const optionalSpan = labelElement.querySelector('.optional-indicator')
    const requiredSpan = labelElement.querySelector('.required-indicator')

    if (isRequired) {
      // Hide optional, show required
      if (optionalSpan) optionalSpan.classList.add('hidden')
      if (requiredSpan) requiredSpan.classList.remove('hidden')
    } else {
      // Show optional, hide required
      if (optionalSpan) optionalSpan.classList.remove('hidden')
      if (requiredSpan) requiredSpan.classList.add('hidden')
    }
  }
}
