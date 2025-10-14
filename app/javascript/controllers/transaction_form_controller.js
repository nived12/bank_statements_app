import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transaction-form"
export default class extends Controller {
  static targets = ["transactionType", "amount", "bankAccount", "transferAccount", "transferField", "bankAccountLabel", "bankAccountHelp"]

  connect() {
    // Set up event listeners
    if (this.hasTransactionTypeTarget && this.hasAmountTarget) {
      this.transactionTypeTarget.addEventListener('change', () => this.handleAmountSign())
      this.amountTarget.addEventListener('blur', () => this.formatAndHandleAmount())
    }

    // Apply initial state (transfer field visibility and amount sign)
    this.handleAmountSign()
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
        this.bankAccountLabelTarget.textContent = this.data.get('transferFromLabel') || 'De:'
      }
      if (this.hasBankAccountHelpTarget) {
        this.bankAccountHelpTarget.textContent = this.data.get('transferFromHelp') || ''
      }
    } else {
      this.transferFieldTarget.classList.add('hidden')
      this.transferAccountTarget.required = false
      this.transferAccountTarget.value = ''

      if (this.hasBankAccountLabelTarget) {
        this.bankAccountLabelTarget.textContent = this.data.get('bankAccountLabel') || ''
      }
      if (this.hasBankAccountHelpTarget) {
        this.bankAccountHelpTarget.textContent = this.data.get('bankAccountHelp') || ''
      }
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
