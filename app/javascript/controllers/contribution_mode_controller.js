import ModeController from "./mode_base_controller"

// Connects to data-controller="contribution-mode"
// Goal savings: "remaining" = target_amount - current_amount, funded by
// target_contribution_amount at contribution_frequency.
export default class extends ModeController {
  computeSuggestedPeriods() {
    const targetAmountField = this.element.querySelector('input[name="saving[target_amount]"]')
    const currentAmountField = this.element.querySelector('input[name="saving[opening_balance]"]')
    const contributionField = this.element.querySelector('input[name="saving[target_contribution_amount]"]')

    if (!targetAmountField || !currentAmountField || !contributionField) {
      return { action: "abort" }
    }

    const targetAmount = this.cleanValue(targetAmountField.value)
    const currentAmount = this.cleanValue(currentAmountField.value)
    const contributionAmount = this.cleanValue(contributionField.value)
    const messages = this.suggestedDateDisplayTarget.dataset

    if (contributionAmount <= 0) {
      return { action: "message", text: messages.enterAmountText }
    }
    if (targetAmount <= 0) {
      return { action: "message", text: messages.enterTargetAmountText }
    }

    const remaining = targetAmount - currentAmount
    if (remaining <= 0) {
      return { action: "message", text: messages.goalReachedText }
    }

    const frequencyField = this.element.querySelector('select[name="saving[contribution_frequency]"]')
    const frequency = frequencyField ? frequencyField.value : 'monthly'
    return { action: "date", periodsNeeded: Math.ceil(remaining / contributionAmount), frequency }
  }

  computeCalculatedRemaining() {
    const targetAmountField = this.element.querySelector('input[name="saving[target_amount]"]')
    const currentAmountField = this.element.querySelector('input[name="saving[opening_balance]"]')
    const targetDateField = this.element.querySelector('input[name="saving[target_date]"]')
    const frequencyField = this.element.querySelector('select[name="saving[contribution_frequency]"]')

    if (!targetAmountField || !currentAmountField || !targetDateField) {
      return { action: "abort" }
    }

    const targetAmount = this.cleanValue(targetAmountField.value)
    const currentAmount = this.cleanValue(currentAmountField.value)
    const targetDateValue = targetDateField.value
    const frequency = frequencyField ? frequencyField.value : 'monthly'

    if (targetAmount <= 0 || !targetDateValue) {
      return { action: "zero" }
    }

    const remaining = targetAmount - currentAmount
    if (remaining <= 0) {
      return { action: "zero" }
    }

    return { action: "compute", remaining, targetDateValue, frequency }
  }
}
