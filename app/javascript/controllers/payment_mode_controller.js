import ModeController from "./mode_base_controller"

// Connects to data-controller="payment-mode"
// Debt payoff: "remaining" = current_balance, paid down by
// target_payment_amount at payment_frequency. Simple calculation without
// interest (the backend handles actual interest calculation).
export default class extends ModeController {
  computeSuggestedPeriods() {
    const currentBalanceField = this.element.querySelector('input[name="debt[opening_balance]"]')
    const paymentField = this.element.querySelector('input[name="debt[target_payment_amount]"]')

    if (!currentBalanceField || !paymentField) {
      return { action: "abort" }
    }

    const currentBalance = this.cleanValue(currentBalanceField.value)
    const paymentAmount = this.cleanValue(paymentField.value)
    const messages = this.suggestedDateDisplayTarget.dataset

    if (paymentAmount <= 0) {
      return { action: "message", text: messages.enterAmountText }
    }
    if (currentBalance <= 0) {
      return { action: "message", text: messages.debtPaidOffText }
    }

    const frequencyField = this.element.querySelector('select[name="debt[payment_frequency]"]')
    const frequency = frequencyField ? frequencyField.value : 'monthly'
    return { action: "date", periodsNeeded: Math.ceil(currentBalance / paymentAmount), frequency }
  }

  computeCalculatedRemaining() {
    const currentBalanceField = this.element.querySelector('input[name="debt[opening_balance]"]')
    const targetDateField = this.element.querySelector('input[name="debt[target_payoff_date]"]')
    const frequencyField = this.element.querySelector('select[name="debt[payment_frequency]"]')

    if (!currentBalanceField || !targetDateField) {
      return { action: "abort" }
    }

    const currentBalance = this.cleanValue(currentBalanceField.value)
    const targetDateValue = targetDateField.value
    const frequency = frequencyField ? frequencyField.value : 'monthly'

    if (currentBalance <= 0 || !targetDateValue) {
      return { action: "zero" }
    }

    return { action: "compute", remaining: currentBalance, targetDateValue, frequency }
  }
}
