import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "adjustments", "adjustmentsValue"]

  connect() {
    this.updateAdjustments()
  }

  add(event) {
    event.preventDefault()
    const stamp = new Date().getTime()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, stamp)
    this.listTarget.insertAdjacentHTML("beforeend", content)
    this.updateAdjustments()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-transaction-items-row]")
    const destroyInput = row.querySelector("input[name*='_destroy']")
    if (destroyInput) {
      destroyInput.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
    this.updateAdjustments()
  }

  updateAdjustments() {
    if (!this.hasAdjustmentsTarget) return

    const amountField = document.querySelector("[data-transaction-form-target='amount']")
    const rawAmount = amountField ? amountField.value.replace(/,/g, "") : "0"
    const totalAmount = Math.abs(parseFloat(rawAmount) || 0)

    let itemsSum = 0
    const rows = this.listTarget.querySelectorAll("[data-transaction-items-row]")
    rows.forEach(row => {
      if (row.style.display === "none") return
      const amountInput = row.querySelector("[data-item-amount]")
      if (amountInput) itemsSum += Math.abs(parseFloat(amountInput.value) || 0)
    })

    const taxInput = this.element.querySelector("[data-tax-input]")
    const tipInput = this.element.querySelector("[data-tip-input]")
    const tax = Math.abs(parseFloat(taxInput?.value) || 0)
    const tip = Math.abs(parseFloat(tipInput?.value) || 0)

    const adjustment = totalAmount - itemsSum - tax - tip

    if (totalAmount === 0 || Math.abs(adjustment) < 0.005) {
      this.adjustmentsTarget.classList.add("hidden")
    } else {
      this.adjustmentsTarget.classList.remove("hidden")
      const prefix = adjustment >= 0 ? "+" : "-"
      this.adjustmentsValueTarget.textContent = `${prefix}$${Math.abs(adjustment).toFixed(2)}`
    }
  }
}
