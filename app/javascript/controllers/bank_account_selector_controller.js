import { Controller } from "@hotwired/stimulus"

// Bank Account Selector - Dropdown for selecting bank accounts
export default class extends Controller {
  static targets = ["menu", "selectedText", "hiddenInput"]

  connect() {
    // Bind click outside to close
    this.clickOutsideHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle(event) {
    event?.preventDefault()
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    // Add click outside listener after a brief delay
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 10)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  selectBankAccount(event) {
    event.preventDefault()
    const item = event.currentTarget
    const accountId = item.dataset.bankAccountId
    const accountName = item.dataset.bankAccountName

    // Update hidden input
    this.hiddenInputTarget.value = accountId

    // Update display
    this.selectedTextTarget.textContent = accountName

    this.close()
  }

  selectAccount(event) {
    event.preventDefault()
    const item = event.currentTarget
    const accountId = item.dataset.accountId
    const accountName = item.dataset.accountName

    // Update hidden input
    this.hiddenInputTarget.value = accountId

    // Update display
    this.selectedTextTarget.textContent = accountName

    this.close()
  }

  clearSelection(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.hiddenInputTarget.value = ""
    this.selectedTextTarget.textContent = this.selectedTextTarget.dataset.placeholder || "Elige una cuenta bancaria"
    this.close()
  }
}
