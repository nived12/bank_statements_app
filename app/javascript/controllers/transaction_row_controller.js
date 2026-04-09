import { Controller } from "@hotwired/stimulus"

/**
 * Inline editing for transaction table rows.
 * Allows editing description, amount, and transaction type directly in the table.
 * Follows the same pattern as rule_row_controller.js.
 *
 * UX:
 * - Click a cell to activate that field
 * - Cancel (✗) appears immediately; Save (✓) appears only when dirty
 * - Action buttons (edit/statement/delete) are hidden while editing
 * - Enter saves, Escape cancels
 * - Amount shows +/- sign based on transaction type
 */
export default class extends Controller {
  static targets = [
    "descriptionDisplay", "descriptionInput",
    "amountDisplay", "amountInput", "amountInputWrapper", "amountSign",
    "typeDisplay", "typeSelect",
    "saveBtn", "cancelBtn",
    "actionButtons"
  ]
  static values = {
    url: String,
    originalDescription: String,
    originalAmount: String,
    originalType: String
  }

  connect() {
    this.descriptionInputTarget.value = this.originalDescriptionValue
    this.amountInputTarget.value = this.originalAmountValue
    this.typeSelectTarget.value = this.originalTypeValue
  }

  activateDescription(event) {
    if (!this.descriptionInputTarget.classList.contains("hidden")) return

    this.enterEditMode()
    this.descriptionDisplayTarget.classList.add("hidden")
    this.descriptionInputTarget.classList.remove("hidden")
    this.descriptionInputTarget.focus()
    this.descriptionInputTarget.select()
  }

  activateAmount(event) {
    if (!this.amountInputWrapperTarget.classList.contains("hidden")) return

    this.enterEditMode()
    this.amountDisplayTarget.classList.add("hidden")
    this.amountInputWrapperTarget.classList.remove("hidden")
    this.amountInputWrapperTarget.classList.add("flex")
    this.amountInputTarget.focus()
    this.amountInputTarget.select()
  }

  activateType(event) {
    if (!this.typeSelectTarget.classList.contains("hidden")) return

    this.enterEditMode()
    this.typeDisplayTarget.classList.add("hidden")
    this.typeSelectTarget.classList.remove("hidden")
    this.typeSelectTarget.focus()
  }

  // Called when transaction type changes — updates the amount sign prefix and auto-saves
  handleTypeChange() {
    const isIncome = ["income", "transfer_in"].includes(this.typeSelectTarget.value)
    this.amountSignTarget.textContent = isIncome ? "+" : "-"
    this.amountSignTarget.className = `text-sm font-medium mr-0.5 ${isIncome ? "text-green-600" : "text-red-600"}`
    this.save()
  }

  checkDirty() {
    const dirty =
      this.descriptionInputTarget.value !== this.originalDescriptionValue ||
      this.amountInputTarget.value !== this.originalAmountValue ||
      this.typeSelectTarget.value !== this.originalTypeValue

    if (dirty) {
      this.saveBtnTarget.classList.remove("hidden")
    } else {
      this.saveBtnTarget.classList.add("hidden")
    }
  }

  async save(event) {
    if (event) event.preventDefault()

    // If nothing changed, just cancel out of edit mode
    const dirty =
      this.descriptionInputTarget.value !== this.originalDescriptionValue ||
      this.amountInputTarget.value !== this.originalAmountValue ||
      this.typeSelectTarget.value !== this.originalTypeValue

    if (!dirty) {
      this.cancel()
      return
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const typeValue = this.typeSelectTarget.value
    const absAmount = parseFloat(this.amountInputTarget.value.replace(/,/g, "")) || 0
    const isIncome = ["income", "transfer_in"].includes(typeValue)
    const signedAmount = isIncome ? absAmount : -absAmount

    const body = new URLSearchParams({
      "transaction[concept]": this.descriptionInputTarget.value,
      "transaction[amount]": signedAmount.toString(),
      "transaction[transaction_type]": typeValue,
      "_method": "patch"
    })

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: body.toString()
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        this.cancel()
      }
    } catch (error) {
      console.error("Failed to save transaction:", error)
      this.cancel()
    }
  }

  cancel(event) {
    if (event) event.preventDefault()

    // Restore description
    this.descriptionInputTarget.value = this.originalDescriptionValue
    this.descriptionInputTarget.classList.add("hidden")
    this.descriptionDisplayTarget.classList.remove("hidden")

    // Restore amount
    this.amountInputTarget.value = this.originalAmountValue
    this.amountInputWrapperTarget.classList.add("hidden")
    this.amountInputWrapperTarget.classList.remove("flex")
    this.amountDisplayTarget.classList.remove("hidden")

    // Restore type
    this.typeSelectTarget.value = this.originalTypeValue
    this.typeSelectTarget.classList.add("hidden")
    this.typeDisplayTarget.classList.remove("hidden")

    this.exitEditMode()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  // --- private helpers ---

  enterEditMode() {
    this.actionButtonsTarget.classList.add("hidden")
    this.cancelBtnTarget.classList.remove("hidden")
  }

  exitEditMode() {
    this.saveBtnTarget.classList.add("hidden")
    this.cancelBtnTarget.classList.add("hidden")
    this.actionButtonsTarget.classList.remove("hidden")
  }
}
