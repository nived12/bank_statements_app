import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submitButton"]

  connect() {
    this.originalFormData = new FormData(this.formTarget)
    this.isNewRecord = this.checkIfNewRecord()
    this.checkChanges()
  }

  checkIfNewRecord() {
    // Check if this is a new record by looking at the form action and method
    const formAction = this.formTarget.action
    const method = this.formTarget.method?.toLowerCase() || this.formTarget.getAttribute('method')?.toLowerCase()

    // A form is new if:
    // 1. The action ends with /bank_accounts (no ID in path)
    // 2. The method is POST (not PATCH)
    const isPost = method === 'post' || method === 'get' // Rails form_with defaults to POST
    const endsWithBankAccounts = formAction.endsWith('/bank_accounts')

    return isPost && endsWithBankAccounts
  }

  checkChanges() {
    const currentFormData = new FormData(this.formTarget)
    let hasChanges = false
    let isValid = true

    // Check if form is valid (all required fields are filled)
    const requiredFields = this.formTarget.querySelectorAll('[required]')

    requiredFields.forEach(field => {
      // For select fields, check if a valid option is selected (not the prompt)
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
    if (this.hasSubmitButtonTarget) {
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
  }

  submit(event) {
    event.preventDefault()
    if (!this.submitButtonTarget.disabled) {
      this.formTarget.requestSubmit()
    }
  }
}
