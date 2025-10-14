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

    // Populate the create modal for editing
    this.populateForm(data)

    // Update modal title and button
    this.updateModalUI()

    // Set form to PATCH method for update
    this.setFormMethod('patch', transactionId)

    // Disable type and account fields for editing
    this.disableImmutableFields(data.transaction_type)

    // Set date max to today
    const dateInput = document.getElementById('create_date')
    if (dateInput) {
      const today = new Date()
      const year = today.getFullYear()
      const month = String(today.getMonth() + 1).padStart(2, '0')
      const day = String(today.getDate()).padStart(2, '0')
      dateInput.max = `${year}-${month}-${day}`
    }

    // Open modal
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
    } else {
      document.getElementById('createTransactionModal').classList.remove('hidden')
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

    // Set form values
    const typeSelect = document.getElementById('create_transaction_type')
    const bankAccountSelect = document.getElementById('create_bank_account_id')
    const dateInput = document.getElementById('create_date')
    const amountInput = document.getElementById('create_amount')
    const descriptionInput = document.getElementById('create_description')
    const categorySelect = document.getElementById('create_category_id')
    const merchantInput = document.getElementById('create_merchant')
    const referenceInput = document.getElementById('create_reference')
    const transferAccountSelect = document.getElementById('create_transfer_account_id')

    if (typeSelect) typeSelect.value = transactionTypeValue
    if (bankAccountSelect) bankAccountSelect.value = sourceBankAccountId
    if (dateInput) dateInput.value = data.date
    if (amountInput) amountInput.value = Math.abs(parseFloat(data.amount) || 0)
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
  }

  // Update modal title and button for edit mode
  updateModalUI() {
    const modal = document.getElementById('createTransactionModal')
    if (!modal) return

    const titleElement = modal.querySelector('h3')
    if (titleElement) {
      titleElement.textContent = this.data.get('editTitle') || 'Edit Transaction'
    }

    const submitButton = modal.querySelector('button[type="submit"]')
    if (submitButton) {
      submitButton.textContent = this.data.get('saveChanges') || 'Save Changes'
    }
  }

  // Set form to PATCH method for updates
  setFormMethod(method, transactionId) {
    const form = document.getElementById('createTransactionForm')
    if (!form) return

    form.action = `/transactions/${transactionId}`

    let methodInput = form.querySelector('input[name="_method"]')
    if (!methodInput) {
      methodInput = document.createElement('input')
      methodInput.type = 'hidden'
      methodInput.name = '_method'
      form.appendChild(methodInput)
    }
    methodInput.value = method
  }

  // Disable fields that shouldn't change during edit
  disableImmutableFields(transactionType) {
    const typeSelect = document.getElementById('create_transaction_type')
    const bankAccountSelect = document.getElementById('create_bank_account_id')
    const transferAccountSelect = document.getElementById('create_transfer_account_id')

    if (typeSelect) typeSelect.disabled = true
    if (bankAccountSelect) bankAccountSelect.disabled = true
    if (transactionType === 'transfer_out' && transferAccountSelect) {
      transferAccountSelect.disabled = true
    }
  }
}
