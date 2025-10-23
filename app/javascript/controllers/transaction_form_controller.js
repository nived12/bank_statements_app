import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transaction-form"
export default class extends Controller {
  static targets = [
    "transactionType",
    "amount",
    "bankAccount",
    "transferAccount",
    "transferField",
    "bankAccountLabel",
    "bankAccountHelp",
    "amountSign",
    "amountCurrency",
    "form",
    "goalsContainer",
    "goalsToggleText",
    "goalsToggleIcon",
    "goalCheckbox",
    "savingsContainer",
    "savingsToggleText",
    "savingsToggleIcon",
    "savingCheckbox",
    "debtsContainer",
    "debtsToggleText",
    "debtsToggleIcon",
    "debtCheckbox"
  ]

  static values = {
    transferFromLabel: String,
    transferFromHelp: String,
    bankAccountLabel: String,
    bankAccountHelp: String
  }

  connect() {
    // Set up event listeners
    if (this.hasTransactionTypeTarget && this.hasAmountTarget) {
      this.transactionTypeTarget.addEventListener('change', () => this.handleAmountSign())
      this.amountTarget.addEventListener('blur', () => this.formatAndHandleAmount())
      this.amountTarget.addEventListener('input', () => this.enforceDecimalPlaces())
    }

    // Apply initial state (transfer field visibility and amount sign)
    this.handleAmountSign()

    // Format any existing values with commas
    this.formatExistingValue()

    // Add form submission handler to strip commas
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }
  }

  // Format existing value on page load
  formatExistingValue() {
    if (this.hasAmountTarget && this.amountTarget.value) {
      const value = parseFloat(this.amountTarget.value.replace(/,/g, ''))
      if (!isNaN(value)) {
        this.amountTarget.value = this.formatNumberWithCommas(value.toFixed(2))
      }
    }
  }

  // Strip commas from amount field before form submission
  stripCommasOnSubmit(event) {
    if (this.hasAmountTarget && this.amountTarget.value) {
      this.amountTarget.value = this.amountTarget.value.replace(/,/g, '')
    }
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces() {
    if (!this.hasAmountTarget) return

    let value = this.amountTarget.value

    // Remove any non-numeric characters except decimal point, minus sign, and commas
    value = value.replace(/[^0-9.,-]/g, '')

    // Remove all commas for processing
    value = value.replace(/,/g, '')

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
    let value = this.amountTarget.value.replace(/,/g, '')
    let amount = parseFloat(value)

    // If empty or not a valid number, just handle visibility
    if (isNaN(amount)) {
      this.handleAmountSign()
      return
    }

    // Format to 2 decimal places with commas
    amount = parseFloat(amount.toFixed(2))
    this.amountTarget.value = this.formatNumberWithCommas(amount.toFixed(2))

    // Now handle sign
    this.handleAmountSign()
  }

  // Handle amount sign based on transaction type
  handleAmountSign() {
    if (!this.hasTransactionTypeTarget || !this.hasAmountTarget) return

    const transactionType = this.transactionTypeTarget.value
    // Remove commas for parsing
    let value = this.amountTarget.value.replace(/,/g, '')
    let amount = parseFloat(value)

    // Update transfer field visibility
    this.updateTransferFieldVisibility(transactionType)

    if (isNaN(amount) || amount === 0) return

    if (transactionType === 'income') {
      // Income should be positive
      if (amount < 0) {
        this.amountTarget.value = this.formatNumberWithCommas(Math.abs(amount).toFixed(2))
      }
    } else if (transactionType === 'fixed_expense' || transactionType === 'variable_expense') {
      // Expenses should be negative
      if (amount > 0) {
        this.amountTarget.value = this.formatNumberWithCommas((-amount).toFixed(2))
      }
    } else if (transactionType === 'transfer_out') {
      // Transfers should always be positive (service handles the sign)
      if (amount < 0) {
        this.amountTarget.value = this.formatNumberWithCommas(Math.abs(amount).toFixed(2))
      }
    }
  }

  // Helper method to add comma separators to numbers
  formatNumberWithCommas(value) {
    // Handle negative numbers
    const isNegative = value.toString().startsWith('-')
    const absoluteValue = isNegative ? value.toString().substring(1) : value.toString()

    const parts = absoluteValue.split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")

    return (isNegative ? '-' : '') + parts.join(".")
  }

  // Update transfer field visibility and labels
  updateTransferFieldVisibility(transactionType) {
    if (!this.hasTransferFieldTarget || !this.hasTransferAccountTarget) return

    if (transactionType === 'transfer_out') {
      this.transferFieldTarget.classList.remove('hidden')
      this.transferAccountTarget.required = true

      if (this.hasBankAccountLabelTarget) {
        this.bankAccountLabelTarget.textContent = this.transferFromLabelValue || 'De:'
      }
      if (this.hasBankAccountHelpTarget) {
        this.bankAccountHelpTarget.textContent = this.transferFromHelpValue || ''
      }
    } else {
      this.transferFieldTarget.classList.add('hidden')
      this.transferAccountTarget.required = false
      this.transferAccountTarget.value = ''

      if (this.hasBankAccountLabelTarget) {
        this.bankAccountLabelTarget.textContent = this.bankAccountLabelValue || ''
      }
      if (this.hasBankAccountHelpTarget) {
        this.bankAccountHelpTarget.textContent = this.bankAccountHelpValue || ''
      }
    }

    // Update mobile amount styling
    this.updateMobileAmountStyling(transactionType)
  }

  // Update mobile amount sign and color styling
  updateMobileAmountStyling(transactionType) {
    // Only update if mobile targets exist
    if (!this.hasAmountSignTarget || !this.hasAmountCurrencyTarget) return

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

  // Handle form submission - re-enable disabled fields
  submit(event) {
    const form = event.target

    // Re-enable any disabled fields before submission
    const disabledFields = form.querySelectorAll('[disabled]')
    disabledFields.forEach(field => {
      field.disabled = false
    })
  }
}
