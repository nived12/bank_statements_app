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
    this.checkChanges()
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
