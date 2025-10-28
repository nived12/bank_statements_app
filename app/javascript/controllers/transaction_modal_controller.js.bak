import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transaction-modal"
export default class extends Controller {
  static targets = [
    "modal",
    "title",
    "subtitle",
    "mobileTitle",
    "submitButton",
    "desktopContent",
    "mobileContent"
  ]

  static values = {
    createTitle: String,
    editTitle: String,
    createButton: String,
    editButton: String,
    mode: { type: String, default: "create" } // "create" or "edit"
  }

  connect() {
    // Set initial date to today when form loads
    this.setDateToToday()
  }

  // Open modal in create mode
  open(event) {
    if (event) event.preventDefault()
    this.openCreate()
  }

  openCreate() {
    this.modeValue = "create"
    this.updateUI()
    this.resetForm()
    this.setDateToToday()
    this.show()
  }

  // Open modal in edit mode (called by transaction-edit controller)
  openEdit() {
    this.modeValue = "edit"
    this.updateUI()
    this.show()
  }

  // Close modal
  close(event) {
    if (event) event.preventDefault()
    this.hide()

    // Reset to create mode and clear form after animation
    setTimeout(() => {
      this.modeValue = "create"
      this.resetForm()
    }, 300)
  }

  // Close modal when clicking outside (desktop only)
  closeOnOutsideClick(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  // Show modal
  show() {
    this.modalTarget.classList.remove('hidden')

    // Add animation for mobile
    if (this.hasMobileContentTarget) {
      const mobileContent = this.mobileContentTarget.querySelector('.mobile-transaction-modal-content')
      if (mobileContent) {
        setTimeout(() => {
          mobileContent.style.transform = 'translateY(0)'
        }, 10)
      }
    }
  }

  // Hide modal
  hide() {
    // Animate out mobile content
    if (this.hasMobileContentTarget) {
      const mobileContent = this.mobileContentTarget.querySelector('.mobile-transaction-modal-content')
      if (mobileContent) {
        mobileContent.style.transform = 'translateY(100%)'
      }
    }

    // Hide modal after animation
    setTimeout(() => {
      this.modalTarget.classList.add('hidden')
    }, 200)
  }

  // Update UI based on mode (create vs edit)
  updateUI() {
    const isCreate = this.modeValue === "create"

    // Update desktop title
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = isCreate ? this.createTitleValue : this.editTitleValue
    }

    // Update mobile title
    if (this.hasMobileTitleTarget) {
      this.mobileTitleTarget.textContent = isCreate ? this.createTitleValue : this.editTitleValue
    }

    // Update submit button text (desktop only, mobile uses save icon)
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.textContent = isCreate ? this.createButtonValue : this.editButtonValue
    }

    // Hide/show subtitle (only show in create mode)
    if (this.hasSubtitleTarget) {
      this.subtitleTarget.classList.toggle('hidden', !isCreate)
    }
  }

  // Submit form (for mobile save button in header)
  submitForm() {
    // Find the visible form (mobile on small screens, desktop on large screens)
    const isMobile = window.innerWidth < 768 // md breakpoint
    const forms = this.element.querySelectorAll('form')

    if (forms.length === 0) return

    // Submit mobile form (second form) on mobile, desktop form (first) on desktop
    const formToSubmit = isMobile ? forms[1] || forms[0] : forms[0]
    if (formToSubmit) {
      formToSubmit.requestSubmit()
    }
  }

  // Reset form to initial state
  resetForm() {
    const forms = this.element.querySelectorAll('form')
    if (forms.length === 0) return

    forms.forEach(form => {
      // Reset form fields
      form.reset()

      // Reset form action to POST for create
      form.action = '/transactions'
      form.method = 'post'

      // Remove PATCH method input if it exists
      const methodInput = form.querySelector('input[name="_method"]')
      if (methodInput) {
        methodInput.remove()
      }

      // Set default transaction type to variable_expense
      const typeSelect = form.querySelector('[data-transaction-form-target="transactionType"]')
      if (typeSelect) {
        typeSelect.value = 'variable_expense'
        // Trigger change event to update UI
        typeSelect.dispatchEvent(new Event('change'))
      }

      // Uncheck all goal checkboxes and hide goals section
      const goalCheckboxes = form.querySelectorAll('[data-transaction-form-target="goalCheckbox"]')
      goalCheckboxes.forEach(checkbox => {
        checkbox.checked = false
      })

      // Hide goals container and reset toggle button
      const goalsContainer = form.querySelector('[data-transaction-form-target="goalsContainer"]')
      if (goalsContainer && !goalsContainer.classList.contains('hidden')) {
        goalsContainer.classList.add('hidden')

        // Reset toggle button text and icon
        const toggleText = form.querySelector('[data-transaction-form-target="goalsToggleText"]')
        const toggleIcon = form.querySelector('[data-transaction-form-target="goalsToggleIcon"]')

        if (toggleText) {
          toggleText.textContent = toggleText.getAttribute('data-show-text') || 'Show Goals'
        }
        if (toggleIcon) {
          toggleIcon.classList.remove('rotate-180')
        }
      }
    })

    // Set date to today (for all forms)
    this.setDateToToday()

    // Re-enable all fields (in case they were disabled during edit)
    this.enableAllFields()
  }

  // Set date input to today
  setDateToToday() {
    const dateInputs = this.element.querySelectorAll('[data-transaction-form-target="date"]')
    const today = new Date().toISOString().split('T')[0]

    dateInputs.forEach(input => {
      if (input && !input.value) {
        input.value = today
      }
    })
  }

  // Enable all form fields
  enableAllFields() {
    const forms = this.element.querySelectorAll('form')
    if (forms.length === 0) return

    forms.forEach(form => {
      // Re-enable all disabled fields
      const disabledFields = form.querySelectorAll('[disabled]')
      disabledFields.forEach(field => {
        field.disabled = false
      })
    })
  }
}
