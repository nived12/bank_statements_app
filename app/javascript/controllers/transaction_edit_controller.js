import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transaction-edit"
export default class extends Controller {
  static targets = ["modal"]
  static values = { editingId: String }

  // Open edit modal with transaction data
  open(event) {
    event.preventDefault()

    const transactionId = event.currentTarget.dataset.transactionId || event.params.transactionId
    this.editingIdValue = transactionId

    // Get transaction data from row or card
    const data = this.getTransactionData(transactionId)
    if (!data) {
      console.error('Could not find transaction data for ID:', transactionId)
      return
    }

    // Populate the form with transaction data
    this.populateForm(data)

    // Set form to PATCH method for update
    this.setFormMethod('patch', transactionId)

    // Disable type and account fields for editing
    this.disableImmutableFields(data.transaction_type)

    // Get the transaction-modal controller and open in edit mode
    const modalElement = document.getElementById('transactionModal')
    if (modalElement) {
      const modalController = this.application.getControllerForElementAndIdentifier(
        modalElement,
        'transaction-modal'
      )
      if (modalController) {
        modalController.openEdit()
      }
    }
  }

  // Get transaction data from desktop row or mobile card
  getTransactionData(transactionId) {
    // Try mobile card first
    let element = document.querySelector(`.mobile-transaction-card[data-transaction-id="${transactionId}"]`)

    if (element) {
      return {
        id: transactionId,
        description: element.dataset.description || '',
        amount: element.dataset.amount || '',
        date: element.dataset.date || '',
        transaction_type: element.dataset.transactionType || '',
        category_id: element.dataset.categoryId || '',
        bank_account_id: element.dataset.accountId || '',
        merchant: element.dataset.merchant || '',
        reference: element.dataset.reference || '',
        transfer_account_id: element.dataset.transferAccountId || ''
      }
    }

    // Try desktop table row
    element = document.querySelector(`.transactions-table-row[data-transaction-id="${transactionId}"]`)

    if (element) {
      const dateCell = element.querySelector('[data-date]')
      const descriptionCell = element.querySelector('[data-description]')
      const amountCell = element.querySelector('[data-amount]')
      const categoryCell = element.querySelector('[data-category-id]')
      const typeCell = element.querySelector('[data-transaction-type]')
      const merchantCell = element.querySelector('[data-merchant]')
      const referenceCell = element.querySelector('[data-reference]')

      return {
        id: transactionId,
        description: descriptionCell?.dataset.description || '',
        amount: amountCell?.dataset.amount || '',
        date: dateCell?.dataset.date || '',
        transaction_type: typeCell?.dataset.transactionType || '',
        category_id: categoryCell?.dataset.categoryId || '',
        bank_account_id: element.dataset.bankAccountId || '',
        merchant: merchantCell?.dataset.merchant || '',
        reference: referenceCell?.dataset.reference || '',
        transfer_account_id: element.dataset.transferAccountId || ''
      }
    }

    return null
  }

  // Populate form with transaction data
  populateForm(data) {
    // Convert transfer_in to transfer_out for editing (users edit from source perspective)
    let transactionTypeValue = data.transaction_type
    let sourceBankAccountId = data.bank_account_id
    let destinationAccountId = data.transfer_account_id

    if (data.transaction_type === 'transfer_in') {
      transactionTypeValue = 'transfer_out'
      // Swap the accounts since we're viewing from opposite perspective
      sourceBankAccountId = data.transfer_account_id
      destinationAccountId = data.bank_account_id
    }

    // Get all forms in modal (desktop and mobile)
    const forms = document.querySelectorAll('#transactionModal form')
    if (forms.length === 0) return

    // Populate all forms (both desktop and mobile)
    forms.forEach(form => {
      // Set form values using data attributes
      const typeSelect = form.querySelector('[data-transaction-form-target="transactionType"]')
      const bankAccountSelect = form.querySelector('[data-transaction-form-target="bankAccount"]')
      const dateInput = form.querySelector('[data-transaction-form-target="date"]')
      const amountInput = form.querySelector('[data-transaction-form-target="amount"]')
      const descriptionInput = form.querySelector('[data-transaction-form-target="description"]')
      const categorySelect = form.querySelector('[data-transaction-form-target="category"]')
      const merchantInput = form.querySelector('[data-transaction-form-target="merchant"]')
      const referenceInput = form.querySelector('[data-transaction-form-target="reference"]')
      const transferAccountSelect = form.querySelector('[data-transaction-form-target="transferAccount"]')

      if (typeSelect) typeSelect.value = transactionTypeValue
      if (bankAccountSelect) bankAccountSelect.value = sourceBankAccountId
      if (dateInput) dateInput.value = data.date
      if (amountInput) {
        const absAmount = Math.abs(parseFloat(data.amount) || 0)
        amountInput.value = absAmount.toFixed(2)
      }
      if (descriptionInput) descriptionInput.value = data.description
      if (categorySelect) categorySelect.value = data.category_id || ''
      if (merchantInput) merchantInput.value = data.merchant || ''
      if (referenceInput) referenceInput.value = data.reference || ''

      // Handle transfer account for transfer_out
      if (transactionTypeValue === 'transfer_out' && destinationAccountId && transferAccountSelect) {
        transferAccountSelect.value = destinationAccountId
      }

      // Trigger change event to update UI
      if (typeSelect) {
        typeSelect.dispatchEvent(new Event('change'))
      }
    })
  }

  // Set form to PATCH method for updates
  setFormMethod(method, transactionId) {
    const forms = document.querySelectorAll('#transactionModal form')
    if (forms.length === 0) return

    forms.forEach(form => {
      form.action = `/transactions/${transactionId}`

      let methodInput = form.querySelector('input[name="_method"]')
      if (!methodInput) {
        methodInput = document.createElement('input')
        methodInput.type = 'hidden'
        methodInput.name = '_method'
        form.appendChild(methodInput)
      }
      methodInput.value = method
    })
  }

  // Disable fields that shouldn't change during edit
  disableImmutableFields(transactionType) {
    const forms = document.querySelectorAll('#transactionModal form')
    if (forms.length === 0) return

    forms.forEach(form => {
      const typeSelect = form.querySelector('[data-transaction-form-target="transactionType"]')
      const bankAccountSelect = form.querySelector('[data-transaction-form-target="bankAccount"]')
      const transferAccountSelect = form.querySelector('[data-transaction-form-target="transferAccount"]')

      if (typeSelect) typeSelect.disabled = true
      if (bankAccountSelect) bankAccountSelect.disabled = true
      if (transactionType === 'transfer_out' && transferAccountSelect) {
        transferAccountSelect.disabled = true
      }
    })
  }
}
