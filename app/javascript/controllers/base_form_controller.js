import { Controller } from "@hotwired/stimulus"

/**
 * Base form controller with shared validation logic.
 * Handles form state management, change detection, and submit button state.
 *
 * Child controllers should:
 * 1. Call super.connect() in their connect() method
 * 2. Implement getResourcePath() to return the resource path (e.g., '/bank_accounts')
 */
export default class extends Controller {
  static targets = ["form", "submitButton"]

  connect() {
    if (this.hasFormTarget) {
      this.originalFormData = new FormData(this.formTarget)
      this.isNewRecord = this.checkIfNewRecord()
    }
    this.checkChanges()
  }

  /**
   * Determines if the form is for a new record or editing an existing one.
   *
   * Detection logic:
   * - New record: POST method + URL ends with resource path (no ID)
   * - Existing record: PATCH/PUT method + URL contains ID
   *
   * Note: Treats GET as POST because Rails form_with may use GET in some cases,
   * but this should be rare. Most forms use POST for creates and PATCH for updates.
   *
   * @returns {boolean} True if this is a new record form, false if editing
   */
  checkIfNewRecord() {
    if (!this.hasFormTarget) return false

    const formAction = this.formTarget.action
    const method = this.formTarget.method?.toLowerCase() ||
                   this.formTarget.getAttribute('method')?.toLowerCase()

    // A form is new if it's a POST request (not PATCH/PUT)
    const isPost = method === 'post' || method === 'get'

    // Check if the URL ends with the resource name (no ID)
    const resourcePath = this.getResourcePath()
    const endsWithResource = formAction.endsWith(resourcePath)

    return isPost && endsWithResource
  }

  /**
   * Override this method in child controllers to specify the resource path.
   * @returns {string} The resource path (e.g., '/bank_accounts', '/transactions')
   */
  getResourcePath() {
    throw new Error('Child controller must implement getResourcePath()')
  }

  /**
   * Validates all required fields in the form.
   * @returns {boolean} True if all required fields are valid, false otherwise
   */
  validateRequiredFields() {
    const requiredFields = this.formTarget.querySelectorAll('[required]')
    let isValid = true

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

    return isValid
  }

  /**
   * Detects if the form has changed from its original state.
   * @returns {boolean} True if form data has changed, false otherwise
   */
  hasFormChanged() {
    const currentFormData = new FormData(this.formTarget)

    for (let [key, value] of currentFormData.entries()) {
      if (this.originalFormData.get(key) !== value) {
        return true
      }
    }

    return false
  }

  /**
   * Checks form validity and changes, then updates submit button state.
   *
   * Submit button is enabled when:
   * - New record: All required fields are valid
   * - Existing record: All required fields are valid AND form has changes
   */
  checkChanges() {
    if (!this.hasFormTarget || !this.hasSubmitButtonTarget) return

    const isValid = this.validateRequiredFields()
    const hasChanges = this.hasFormChanged()

    // For new records: enable if all required fields are valid
    // For existing records: enable if valid AND has changes
    const shouldEnable = isValid && (this.isNewRecord || hasChanges)

    this.updateSubmitButtonState(shouldEnable)
  }

  /**
   * Updates the submit button visual state and enabled/disabled status.
   * @param {boolean} enabled - Whether the button should be enabled
   */
  updateSubmitButtonState(enabled) {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = !enabled

    if (enabled) {
      this.submitButtonTarget.classList.remove("text-slate-400", "cursor-not-allowed")
      this.submitButtonTarget.classList.add("text-green-600", "hover:bg-green-50")
    } else {
      this.submitButtonTarget.classList.add("text-slate-400", "cursor-not-allowed")
      this.submitButtonTarget.classList.remove("text-green-600", "hover:bg-green-50")
    }
  }

  /**
   * Submits the form via the header submit button.
   * @param {Event} event - The click event
   */
  submit(event) {
    event.preventDefault()
    if (!this.submitButtonTarget.disabled && this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }
}
