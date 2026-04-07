import { Controller } from "@hotwired/stimulus"
import { CurrencyFormatter } from "../utilities/currency_formatter"

// Connects to data-controller="transaction-form"
export default class extends Controller {
  static targets = [
    "transactionType",
    "amount",
    "transferAccount",
    "transferField",
    "amountSign",
    "amountCurrency",
    "currencySymbol",
    "form",
    "submitButton",
    "savingsContainer",
    "savingsToggleText",
    "savingsToggleIcon",
    "savingCheckbox",
    "debtsContainer",
    "debtsToggleText",
    "debtsToggleIcon",
    "debtCheckbox"
  ]

  connect() {
    // Format any existing values with commas
    this.formatExistingValue()

    // Add form submission handler to strip commas
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }

    // Store original form data for change detection
    this.storeOriginalFormData()

    // Add change listeners to all form inputs
    this.setupChangeDetection()

    // Apply initial state (transfer field visibility and amount sign)
    // Use requestAnimationFrame to ensure DOM is fully rendered
    requestAnimationFrame(() => {
      this.handleAmountSign()
      this.checkFormChanges()
    })
  }

  // Handle transaction type change
  handleTransactionTypeChange(event) {
    this.handleAmountSign()
    this.checkFormChanges()
  }

  // Clear placeholder on focus (mobile amount input)
  clearPlaceholder(event) {
    event.target.placeholder = ''
  }

  // Restore placeholder on blur if empty (mobile amount input)
  restorePlaceholder(event) {
    if (event.target.value === '') {
      event.target.placeholder = '0.00'
    }
  }

  // Handle amount input
  handleAmountInput(event) {
    this.enforceDecimalPlaces()
    this.adjustInputWidth()
    this.checkFormChanges()
  }

  // Handle amount blur (format to 2 decimals)
  handleAmountBlur(event) {
    this.formatAndHandleAmount()
    this.adjustInputWidth()
    this.checkFormChanges()
  }

  // Store original form data
  storeOriginalFormData() {
    if (!this.hasFormTarget) return

    this.originalFormData = new FormData(this.formTarget)
  }

  // Setup change detection on all form inputs
  setupChangeDetection() {
    if (!this.hasFormTarget) return

    // Get inputs inside the form
    const inputs = this.formTarget.querySelectorAll('input, select, textarea')
    inputs.forEach(input => {
      input.addEventListener('input', () => this.checkFormChanges())
      input.addEventListener('change', () => this.checkFormChanges())
    })

    // Also get inputs outside the form but connected via form attribute (mobile amount input)
    const formId = this.formTarget.id
    if (formId) {
      const externalInputs = document.querySelectorAll(`input[form="${formId}"], select[form="${formId}"], textarea[form="${formId}"]`)
      externalInputs.forEach(input => {
        input.addEventListener('input', () => this.checkFormChanges())
        input.addEventListener('change', () => this.checkFormChanges())
      })
    }
  }

  // Check if form has changes
  checkFormChanges() {
    if (!this.hasFormTarget || !this.hasSubmitButtonTarget) return

    // For new records, enable if required fields are filled
    const isNew = !this.formTarget.querySelector('input[name="_method"]')

    if (isNew) {
      // Check all required fields generically
      const requiredFields = this.formTarget.querySelectorAll('[required]')
      let isValid = true

      requiredFields.forEach(field => {
        if (field.tagName === 'SELECT') {
          if (!field.value || field.value === '') {
            isValid = false
          }
        } else {
          if (!field.value || field.value.trim() === '') {
            isValid = false
          }
        }
      })

      if (isValid) {
        this.enableSubmitButton()
      } else {
        this.disableSubmitButton()
      }
    } else {
      // For existing records, check if anything changed
      const currentFormData = new FormData(this.formTarget)
      const hasChanges = this.formDataChanged(this.originalFormData, currentFormData)

      if (hasChanges) {
        this.enableSubmitButton()
      } else {
        this.disableSubmitButton()
      }
    }
  }

  // Compare two FormData objects
  formDataChanged(original, current) {
    const originalEntries = Array.from(original.entries())
    const currentEntries = Array.from(current.entries())

    // Check if number of entries changed
    if (originalEntries.length !== currentEntries.length) return true

    // Compare each entry
    for (let i = 0; i < originalEntries.length; i++) {
      const [key1, value1] = originalEntries[i]
      const [key2, value2] = currentEntries[i]

      // Normalize amount values (remove commas)
      const normalizedValue1 = key1 === 'transaction[amount]' ? CurrencyFormatter.stripCommas(value1) : value1
      const normalizedValue2 = key2 === 'transaction[amount]' ? CurrencyFormatter.stripCommas(value2) : value2

      if (key1 !== key2 || normalizedValue1 !== normalizedValue2) return true
    }

    return false
  }

  // Enable submit button
  enableSubmitButton() {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.classList.remove('text-slate-400', 'cursor-not-allowed')
    this.submitButtonTarget.classList.add('text-green-600', 'hover:bg-green-50')
  }

  // Disable submit button
  disableSubmitButton() {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.classList.add('text-slate-400', 'cursor-not-allowed')
    this.submitButtonTarget.classList.remove('text-green-600', 'hover:bg-green-50')
  }

  // Format existing value on page load
  formatExistingValue() {
    if (this.hasAmountTarget && this.amountTarget.value) {
      const value = parseFloat(CurrencyFormatter.stripCommas(this.amountTarget.value))
      if (!isNaN(value)) {
        this.amountTarget.value = CurrencyFormatter.formatWithCommas(value.toFixed(2))
      }
    }
    // Adjust width after formatting
    this.adjustInputWidth()
  }

  // Dynamically adjust input width based on content
  adjustInputWidth() {
    if (!this.hasAmountTarget) return

    // Check if this is the mobile input (has bg-transparent class) vs form input (has border class)
    // Mobile inputs have specific styling and should be dynamic
    // Form inputs should use full container width
    const isMobileInput = this.amountTarget.classList.contains('bg-transparent')

    if (isMobileInput) {
      // Mobile: Calculate width in ch units (character width)
      const value = this.amountTarget.value || this.amountTarget.placeholder
      const length = value.length
      const width = Math.max(5, Math.min(length + 1, 15))
      this.amountTarget.style.width = `${width}ch`
    } else {
      // Desktop/Form: Remove any inline width style to allow full container width
      this.amountTarget.style.width = ''
    }
  }

  // Strip commas from amount field before form submission
  stripCommasOnSubmit(event) {
    if (this.hasAmountTarget && this.amountTarget.value) {
      this.amountTarget.value = CurrencyFormatter.stripCommas(this.amountTarget.value)
    }
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces() {
    if (!this.hasAmountTarget) return

    let value = this.amountTarget.value

    // Remove any non-numeric characters except decimal point, minus sign, and commas
    value = value.replace(/[^0-9.,-]/g, '')

    // Remove all commas for processing
    value = CurrencyFormatter.stripCommas(value)
    // Only allow one decimal point
    const parts = value.split('.')
    if (parts.length > 2) {
      value = parts[0] + '.' + parts.slice(1).join('')
    }

    // Limit to 2 decimal places
    if (parts.length === 2 && parts[1].length > 2) {
      value = parts[0] + '.' + parts[1].substring(0, 2)
    }

    this.amountTarget.value = value
  }

  // Format amount with 2 decimals, comma separators, and handle sign
  formatAndHandleAmount() {
    if (!this.hasAmountTarget) return

    // Remove commas for parsing
    let value = CurrencyFormatter.stripCommas(this.amountTarget.value)
    let amount = parseFloat(value)

    // If empty or not a valid number, just handle visibility
    if (isNaN(amount)) {
      this.handleAmountSign()
      return
    }

    // Format to 2 decimal places with commas
    amount = parseFloat(amount.toFixed(2))
    this.amountTarget.value = CurrencyFormatter.formatWithCommas(amount.toFixed(2))

    // Now handle sign
    this.handleAmountSign()
  }

  // Handle amount sign based on transaction type
  handleAmountSign() {
    if (!this.hasTransactionTypeTarget || !this.hasAmountTarget) return

    const transactionType = this.transactionTypeTarget.value
    // Remove commas for parsing
    let value = CurrencyFormatter.stripCommas(this.amountTarget.value)
    let amount = parseFloat(value)

    // Update transfer field visibility
    this.updateTransferFieldVisibility(transactionType)

    if (isNaN(amount) || amount === 0) return

    // For mobile view with separate sign span, always keep the input value positive
    // The span handles displaying the sign based on transaction type
    // This prevents duplicate minus signs (e.g., "-$ -1,233.00")
    const absoluteAmount = Math.abs(amount)
    this.amountTarget.value = CurrencyFormatter.formatWithCommas(absoluteAmount.toFixed(2))

    // Adjust width after formatting
    this.adjustInputWidth()
  }


  // Update transfer field visibility and labels
  updateTransferFieldVisibility(transactionType) {
    // Only update transfer field if targets exist
    if (this.hasTransferFieldTarget && this.hasTransferAccountTarget) {
      if (transactionType === 'transfer_out') {
        this.transferFieldTarget.classList.remove('hidden')
        this.transferAccountTarget.required = true
      } else {
        this.transferFieldTarget.classList.add('hidden')
        this.transferAccountTarget.required = false
        this.transferAccountTarget.value = ''
      }
    }

    // Always update mobile amount styling (even if transfer targets don't exist)
    this.updateMobileAmountStyling(transactionType)
  }

  // Update mobile amount sign and color styling
  updateMobileAmountStyling(transactionType) {
    // Update mobile-specific targets if they exist
    if (this.hasAmountSignTarget && this.hasAmountCurrencyTarget && this.hasAmountTarget) {
      const amountInput = this.amountTarget

      if (transactionType === 'transfer_out') {
        // Transfers: no sign, neutral color
        this.amountSignTarget.textContent = ''
        this.amountSignTarget.className = 'text-3xl font-bold text-slate-900'
        this.amountCurrencyTarget.className = 'text-3xl font-bold text-slate-900'
        amountInput.classList.remove('text-red-600', 'text-green-600')
        amountInput.classList.add('text-slate-900')
      } else if (transactionType === 'income') {
        // Income: + sign, green color
        this.amountSignTarget.textContent = '+'
        this.amountSignTarget.className = 'text-3xl font-bold text-green-600'
        this.amountCurrencyTarget.className = 'text-3xl font-bold text-green-600'
        amountInput.classList.remove('text-red-600', 'text-slate-900')
        amountInput.classList.add('text-green-600')
      } else {
        // Expenses: - sign, red color
        this.amountSignTarget.textContent = '-'
        this.amountSignTarget.className = 'text-3xl font-bold text-red-600'
        this.amountCurrencyTarget.className = 'text-3xl font-bold text-red-600'
        amountInput.classList.remove('text-green-600', 'text-slate-900')
        amountInput.classList.add('text-red-600')
      }
    }

    // Also update currency symbol for unified forms (desktop/standardized forms)
    this.updateCurrencySymbolColor(transactionType)
  }

  // Update currency symbol color for standardized forms
  updateCurrencySymbolColor(transactionType) {
    if (!this.hasCurrencySymbolTarget) return

    if (transactionType === 'transfer_out') {
      // Transfers: neutral/default color
      this.currencySymbolTarget.classList.remove('text-red-600', 'text-green-600')
      this.currencySymbolTarget.classList.add('text-slate-500')
    } else if (transactionType === 'income') {
      // Income: green color
      this.currencySymbolTarget.classList.remove('text-red-600', 'text-slate-500')
      this.currencySymbolTarget.classList.add('text-green-600')
    } else {
      // Expenses: red color
      this.currencySymbolTarget.classList.remove('text-green-600', 'text-slate-500')
      this.currencySymbolTarget.classList.add('text-red-600')
    }
  }

  // Toggle savings section visibility
  toggleSavings(event) {
    if (event) event.preventDefault()

    // Get all savings containers (both mobile and desktop)
    const containers = this.savingsContainerTargets
    const toggleTexts = this.savingsToggleTextTargets
    const toggleIcons = this.savingsToggleIconTargets

    // Toggle visibility for all containers
    containers.forEach(container => {
      container.classList.toggle('hidden')
    })

    // Check if containers are now visible
    const isVisible = !containers[0]?.classList.contains('hidden')

    // Update all toggle texts and icons
    toggleTexts.forEach(text => {
      text.textContent = isVisible ?
        text.getAttribute('data-hide-text') || 'Hide Savings' :
        text.getAttribute('data-show-text') || 'Show Savings'
    })

    toggleIcons.forEach(icon => {
      if (isVisible) {
        icon.classList.add('rotate-180')
      } else {
        icon.classList.remove('rotate-180')
      }
    })
  }

  // Toggle debts section visibility
  toggleDebts(event) {
    if (event) event.preventDefault()

    // Get all debts containers (both mobile and desktop)
    const containers = this.debtsContainerTargets
    const toggleTexts = this.debtsToggleTextTargets
    const toggleIcons = this.debtsToggleIconTargets

    // Toggle visibility for all containers
    containers.forEach(container => {
      container.classList.toggle('hidden')
    })

    // Check if containers are now visible
    const isVisible = !containers[0]?.classList.contains('hidden')

    // Update all toggle texts and icons
    toggleTexts.forEach(text => {
      text.textContent = isVisible ?
        text.getAttribute('data-hide-text') || 'Hide Debts' :
        text.getAttribute('data-show-text') || 'Show Debts'
    })

    toggleIcons.forEach(icon => {
      if (isVisible) {
        icon.classList.add('rotate-180')
      } else {
        icon.classList.remove('rotate-180')
      }
    })
  }

  // Handle form submission - prevent double submit, re-enable disabled fields
  submit(event) {
    if (this.isSubmitting) {
      event.preventDefault()
      return
    }
    this.isSubmitting = true

    const form = event.target

    // Re-enable disabled inputs/selects/textareas (not buttons) so they submit with the form
    const disabledFields = form.querySelectorAll('input[disabled], select[disabled], textarea[disabled]')
    disabledFields.forEach(field => {
      field.disabled = false
    })

    // Lock submit button to prevent double-submit
    this.disableSubmitButton()
  }

  // Submit form via header button
  submitForm(event) {
    event.preventDefault()
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }
}
