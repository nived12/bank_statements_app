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
    "form"
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
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces() {
    if (!this.hasAmountTarget) return

    let value = this.amountTarget.value

    // Remove any non-numeric characters except decimal point and minus sign
    value = value.replace(/[^0-9.-]/g, '')

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

  // Format amount with 2 decimals and handle sign
  formatAndHandleAmount() {
    if (!this.hasAmountTarget) return

    let amount = parseFloat(this.amountTarget.value)

    // If empty or not a valid number, just handle visibility
    if (isNaN(amount)) {
      this.handleAmountSign()
      return
    }

    // Format to 2 decimal places
    amount = parseFloat(amount.toFixed(2))
    this.amountTarget.value = amount.toFixed(2)

    // Now handle sign
    this.handleAmountSign()
  }

  // Handle amount sign based on transaction type
  handleAmountSign() {
    if (!this.hasTransactionTypeTarget || !this.hasAmountTarget) return

    const transactionType = this.transactionTypeTarget.value
    let amount = parseFloat(this.amountTarget.value)

    // Update transfer field visibility
    this.updateTransferFieldVisibility(transactionType)

    if (isNaN(amount) || amount === 0) return

    if (transactionType === 'income') {
      // Income should be positive
      if (amount < 0) {
        this.amountTarget.value = Math.abs(amount).toFixed(2)
      }
    } else if (transactionType === 'fixed_expense' || transactionType === 'variable_expense') {
      // Expenses should be negative
      if (amount > 0) {
        this.amountTarget.value = (-amount).toFixed(2)
      }
    } else if (transactionType === 'transfer_out') {
      // Transfers should always be positive (service handles the sign)
      if (amount < 0) {
        this.amountTarget.value = Math.abs(amount).toFixed(2)
      }
    }
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
