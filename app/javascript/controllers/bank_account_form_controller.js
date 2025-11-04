import BaseFormController from "./base_form_controller"

/**
 * Bank Account form controller.
 * Handles form validation and submission for bank account create/edit forms.
 */
export default class extends BaseFormController {
  /**
   * Returns the resource path for bank accounts.
   * Used by base controller to detect if form is for a new record.
   * @returns {string} The resource path
   */
  getResourcePath() {
    return '/bank_accounts'
  }
}
