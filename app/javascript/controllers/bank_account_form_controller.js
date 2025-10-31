import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitButton"]

  connect() {
    this.originalFormData = new FormData(this.formTarget)
    this.checkChanges()
  }

  checkChanges() {
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
    if (this.hasSubmitButtonTarget) {
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
  }

  submit(event) {
    event.preventDefault()
    if (!this.submitButtonTarget.disabled) {
      this.formTarget.requestSubmit()
    }
  }
}
