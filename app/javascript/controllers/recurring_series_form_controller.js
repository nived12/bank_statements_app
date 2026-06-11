import BaseFormController from "./base_form_controller"

export default class extends BaseFormController {
  static targets = ["form", "submitButton"]

  connect() {
    super.connect()
    this.syncSegmentButtons()
  }

  setFrequency(event) {
    const frequency = event.currentTarget.dataset.recurringFrequency
    const select = this.element.querySelector("select[name*='frequency']")
    if (!select || !frequency) return

    select.value = frequency
    select.dispatchEvent(new Event("change", { bubbles: true }))
    this.syncSegmentButtons()
  }

  setTxType(event) {
    const txType = event.currentTarget.dataset.recurringTxType
    const select = this.element.querySelector("select[name*='transaction_type']")
    if (!select || !txType) return

    select.value = txType
    select.dispatchEvent(new Event("change", { bubbles: true }))
    this.syncSegmentButtons()
  }

  syncSegmentButtons() {
    const frequencySelect = this.element.querySelector("select[name*='frequency']")
    const txTypeSelect = this.element.querySelector("select[name*='transaction_type']")

    if (frequencySelect) {
      const frequency = frequencySelect.value
      this.element.querySelectorAll("[data-recurring-frequency]").forEach((button) => {
        button.classList.toggle("active", button.dataset.recurringFrequency === frequency)
      })
    }

    if (txTypeSelect) {
      const txType = txTypeSelect.value
      this.element.querySelectorAll("[data-recurring-tx-type]").forEach((button) => {
        button.classList.toggle("active", button.dataset.recurringTxType === txType)
      })
    }
  }

  getResourcePath() {
    return "/recurring_series"
  }
}
