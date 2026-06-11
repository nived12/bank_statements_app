import BaseFormController from "./base_form_controller"

/**
 * Bank Account form controller.
 * Handles form validation and submission for bank account create/edit forms.
 * Toggles bank/account number fields visibility based on account type (cash vs bank).
 */
export default class extends BaseFormController {
  static targets = ["form", "submitButton", "bankField", "accountNumberField", "cashExplanation", "creditExplanation"]

  connect() {
    super.connect()
    this.toggleAccountTypeFields()
    this.syncTypeSegmentButtons()
  }

  /**
   * Returns the resource path for bank accounts.
   * Used by base controller to detect if form is for a new record.
   * @returns {string} The resource path
   */
  getResourcePath() {
    return '/bank_accounts'
  }

  accountTypeChanged() {
    this.toggleAccountTypeFields()
    this.syncTypeSegmentButtons()
    this.checkChanges()
  }

  setAccountType(event) {
    const type = event.currentTarget.dataset.accountType
    const select = this.element.querySelector("select[name*='account_type']")
    if (select) {
      select.value = type
      select.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (type === "cash") {
      const bankInput = this.element.querySelector("input[name*='bank_id']")
      const label = this.element.querySelector("[data-form-picker-target='label']")
      if (bankInput) bankInput.value = ""
      if (label) label.textContent = label.dataset.cashLabel || "Efectivo"
    }

    this.accountTypeChanged()
  }

  bankPicked(event) {
    const { value } = event.detail
    const select = this.element.querySelector("select[name*='account_type']")
    if (!select) return

    if (value === "") {
      select.value = "cash"
    } else if (select.value === "cash") {
      select.value = "debit"
    }
    select.dispatchEvent(new Event("change", { bubbles: true }))
    this.accountTypeChanged()
  }

  syncTypeSegmentButtons() {
    const select = this.element.querySelector("select[name*='account_type']")
    if (!select) return

    const activeType = select.value
    this.element.querySelectorAll("[data-account-type]").forEach((button) => {
      button.classList.toggle("active", button.dataset.accountType === activeType)
    })
  }

  toggleAccountTypeFields() {
    const accountTypeSelect = this.element.querySelector("select[name*='account_type']")
    if (!accountTypeSelect) return

    const isCash = accountTypeSelect.value === "cash"
    const isCredit = accountTypeSelect.value === "credit"

    if (this.hasBankFieldTarget) {
      this.bankFieldTarget.classList.toggle("hidden", isCash)
      const bankSelect = this.bankFieldTarget.querySelector("select")
      if (bankSelect) {
        bankSelect.required = !isCash
        if (isCash) bankSelect.value = ""
      }
    }

    if (this.hasAccountNumberFieldTarget) {
      this.accountNumberFieldTarget.classList.toggle("hidden", isCash)
      const accountInput = this.accountNumberFieldTarget.querySelector("input")
      if (accountInput) {
        accountInput.required = !isCash
        if (isCash) accountInput.value = ""
      }
    }

    if (this.hasCashExplanationTarget) {
      this.cashExplanationTarget.classList.toggle("hidden", !isCash)
    }

    if (this.hasCreditExplanationTarget) {
      this.creditExplanationTarget.classList.toggle("hidden", !isCredit)
    }
  }
}
