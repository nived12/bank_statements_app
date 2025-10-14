import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transaction-modal"
export default class extends Controller {
  static targets = ["modal"]

  // Open modal
  open(event) {
    if (event) event.preventDefault()

    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
    }
  }

  // Close modal
  close(event) {
    if (event) event.preventDefault()

    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
    }

    // Reset form if exists
    this.resetForm()

    // Re-enable fields that may have been disabled during edit
    this.enableAllFields()
  }

  // Close modal when clicking outside
  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  // Reset form to default state
  resetForm() {
    const form = this.element.querySelector('form')
    if (!form) return

    form.reset()

    // Reset form action to create
    form.action = '/transactions'

    // Remove PATCH method input if exists
    const methodInput = form.querySelector('input[name="_method"]')
    if (methodInput) {
      methodInput.remove()
    }

    // Reset modal title
    const titleElement = this.element.querySelector('h3')
    if (titleElement) {
      titleElement.textContent = this.data.get('createTitle') || 'Create Transaction'
    }

    // Reset submit button text
    const submitButton = form.querySelector('button[type="submit"]')
    if (submitButton) {
      submitButton.textContent = this.data.get('createButton') || 'Create Transaction'
    }

    // Set default date to today
    const dateInput = form.querySelector('input[type="date"]')
    if (dateInput) {
      const today = new Date()
      const year = today.getFullYear()
      const month = String(today.getMonth() + 1).padStart(2, '0')
      const day = String(today.getDate()).padStart(2, '0')
      dateInput.value = `${year}-${month}-${day}`
      dateInput.max = `${year}-${month}-${day}`
    }
  }

  // Re-enable all fields
  enableAllFields() {
    const form = this.element.querySelector('form')
    if (!form) return

    const fields = form.querySelectorAll('[disabled]')
    fields.forEach(field => {
      field.disabled = false
    })
  }
}
