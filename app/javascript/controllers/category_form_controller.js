import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nameInput", "iconInput", "submitButton", "form"]

  connect() {
    this.originalName = this.nameInputTarget.value
    this.originalIcon = this.hasIconInputTarget ? this.iconInputTarget.value : null
    this.updateSubmitButton()
  }

  checkChanges() {
    this.updateSubmitButton()
  }

  iconChanged() {
    // Called when icon is selected in the picker
    this.updateSubmitButton()
  }

  updateSubmitButton() {
    const currentName = this.nameInputTarget.value.trim()
    const nameChanged = currentName !== this.originalName
    const nameHasValue = currentName !== ""
    const iconChanged = this.hasIconInputTarget && this.iconInputTarget.value !== this.originalIcon

    // For new records (originalName is empty), enable when name has value
    // For existing records, enable when there are changes
    const shouldEnable = this.originalName === ""
      ? nameHasValue
      : (nameChanged || iconChanged) && nameHasValue

    if (shouldEnable) {
      // Enable button - green checkmark
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed', 'text-slate-400')
      this.submitButtonTarget.classList.add('text-green-600', 'hover:bg-green-50')
    } else {
      // Disable button - gray checkmark
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed', 'text-slate-400')
      this.submitButtonTarget.classList.remove('text-green-600', 'hover:bg-green-50')
    }
  }

  submit(event) {
    event.preventDefault()

    if (!this.submitButtonTarget.disabled) {
      // Find the form element and submit it
      const form = this.element.querySelector('form')
      if (form) {
        form.requestSubmit()
      }
    }
  }
}
