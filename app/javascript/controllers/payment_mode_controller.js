import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="payment-mode"
export default class extends Controller {
  static targets = [
    "modeButton",
    "modeContainer",
    "modeArrow",
    "modeSummary",
    "modeInput",
    "frequencyField",
    "amountField",
    "amountLabelContainer",
    "targetAmountDisplay",
    "fixedAmountInput",
    "calculatedAmountDisplay",
    "targetDateField",
    "targetDateLabelContainer",
    "suggestedDateSection",
    "suggestedDateDisplay",
    "replaceButton",
    "calculatedWarning",
    "calculatedAmountContent",
    "calculatedAmountValue"
  ]

  connect() {
    // Initialize visibility on page load
    this.updateFieldsVisibility()
    this.updateSuggestedDate()
    this.updateCalculatedAmount()
  }

  toggleDropdown() {
    // Toggle the dropdown visibility
    this.modeContainerTarget.classList.toggle("hidden")
    // Rotate arrow
    if (this.modeContainerTarget.classList.contains("hidden")) {
      this.modeArrowTarget.style.transform = "rotate(0deg)"
    } else {
      this.modeArrowTarget.style.transform = "rotate(180deg)"
    }
  }

  selectMode(event) {
    const button = event.currentTarget
    const mode = button.dataset.mode
    const modeText = button.textContent.trim()

    // Update hidden input
    this.modeInputTarget.value = mode

    // Update button summary
    this.modeSummaryTarget.textContent = modeText
    if (mode) {
      this.modeSummaryTarget.classList.remove("text-slate-400")
      this.modeSummaryTarget.classList.add("text-slate-900")
    } else {
      this.modeSummaryTarget.classList.remove("text-slate-900")
      this.modeSummaryTarget.classList.add("text-slate-400")
    }

    // Close dropdown
    this.modeContainerTarget.classList.add("hidden")
    this.modeArrowTarget.style.transform = "rotate(0deg)"

    // Update field visibility
    this.updateFieldsVisibility()

    // Trigger change event on hidden input for form tracking
    this.modeInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  updateFieldsVisibility() {
    const mode = this.modeInputTarget.value

    if (mode === "" || !mode) {
      // No tracking mode - hide both frequency and amount fields
      this.frequencyFieldTarget.classList.add("hidden")
      this.amountFieldTarget.classList.add("hidden")

      // Hide suggested date section
      if (this.hasSuggestedDateSectionTarget) {
        this.suggestedDateSectionTarget.classList.add("hidden")
      }

      // Target date is optional when no mode selected
      this.updateTargetDateLabel(false)
    } else if (mode === "fixed") {
      // Fixed mode - show frequency and amount field with fixed input
      this.frequencyFieldTarget.classList.remove("hidden")
      this.amountFieldTarget.classList.remove("hidden")

      this.targetAmountDisplayTarget.classList.add("hidden")
      this.fixedAmountInputTarget.classList.remove("hidden")
      this.calculatedAmountDisplayTarget.classList.add("hidden")

      // Show suggested date section (only for fixed mode)
      if (this.hasSuggestedDateSectionTarget) {
        this.suggestedDateSectionTarget.classList.remove("hidden")
      }

      // Update label to show as required
      this.updateAmountLabel(true)

      // Target date is optional in fixed mode
      this.updateTargetDateLabel(false)
    } else if (mode === "calculated") {
      // Calculated mode - show frequency and amount field with calculated display
      this.frequencyFieldTarget.classList.remove("hidden")
      this.amountFieldTarget.classList.remove("hidden")

      this.targetAmountDisplayTarget.classList.add("hidden")
      this.fixedAmountInputTarget.classList.add("hidden")
      this.calculatedAmountDisplayTarget.classList.remove("hidden")

      // Hide suggested date section (not needed for calculated mode)
      if (this.hasSuggestedDateSectionTarget) {
        this.suggestedDateSectionTarget.classList.add("hidden")
      }

      // Update label to show as plain (no asterisk, no optional)
      this.updateAmountLabel(false)

      // Target date is required in calculated mode
      this.updateTargetDateLabel(true)

      // Update calculated warning visibility based on target_date
      this.checkTargetDate()

      // Calculate and display the payment amount
      this.updateCalculatedAmount()
    }
  }

  // Update the payment amount label between required and plain
  updateAmountLabel(isRequired) {
    if (!this.hasAmountLabelContainerTarget) return

    const labelText = this.amountLabelContainerTarget.querySelector('label').childNodes[0].textContent.trim()

    if (isRequired) {
      // Show required (red asterisk)
      this.amountLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 mb-2">
          ${labelText}
          <span class="text-red-500">*</span>
        </label>
      `
    } else {
      // Show plain label (no asterisk, no optional text)
      this.amountLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 mb-2">
          ${labelText}
        </label>
      `
    }
  }

  // Update the target payoff date label between required and optional
  updateTargetDateLabel(isRequired) {
    if (!this.hasTargetDateLabelContainerTarget) return

    // Extract the label text (without asterisk or optional text)
    const labelElement = this.targetDateLabelContainerTarget.querySelector('label')
    if (!labelElement) return

    const labelText = labelElement.childNodes[0].textContent.trim()

    if (isRequired) {
      // Show required (red asterisk)
      this.targetDateLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 mb-2">
          ${labelText}
          <span class="text-red-500">*</span>
        </label>
      `
    } else {
      // Show optional
      this.targetDateLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 mb-2">
          ${labelText}
          <span class="text-slate-400 text-xs font-normal ml-1">(optional)</span>
        </label>
      `
    }
  }

  // Check if target_payoff_date is present and toggle warning/content visibility
  checkTargetDate() {
    if (!this.hasTargetDateFieldTarget) return

    const mode = this.modeInputTarget.value
    if (mode !== "calculated") return

    const hasDate = this.targetDateFieldTarget.value && this.targetDateFieldTarget.value.trim() !== ""

    if (this.hasCalculatedWarningTarget && this.hasCalculatedAmountContentTarget) {
      if (hasDate) {
        this.calculatedWarningTarget.classList.add("hidden")
        this.calculatedAmountContentTarget.classList.remove("hidden")
      } else {
        this.calculatedWarningTarget.classList.remove("hidden")
        this.calculatedAmountContentTarget.classList.add("hidden")
      }
    }
  }

  // Calculate and update suggested payoff date for Fixed mode (simple calculation without interest)
  updateSuggestedDate() {
    const mode = this.modeInputTarget.value
    if (mode !== "fixed") return
    if (!this.hasSuggestedDateDisplayTarget || !this.hasReplaceButtonTarget) return

    // Get values from form - use this.element to scope to THIS form instance
    const currentBalanceField = this.element.querySelector('input[name="debt[current_balance]"]')
    const paymentField = this.element.querySelector('input[name="debt[target_payment_amount]"]')

    if (!currentBalanceField || !paymentField) return

    // Clean the value by removing $, commas, and whitespace
    const cleanValue = (value) => {
      if (!value || value.trim() === "") return 0
      return parseFloat(value.replace(/[$,\s]/g, "")) || 0
    }

    const currentBalance = cleanValue(currentBalanceField.value)
    const paymentAmount = cleanValue(paymentField.value)

    if (paymentAmount <= 0) {
      const enterAmountText = this.suggestedDateDisplayTarget.dataset.enterAmountText
      this.suggestedDateDisplayTarget.value = enterAmountText
      this.replaceButtonTarget.disabled = true
      this.replaceButtonTarget.dataset.suggestedDate = ""
      return
    }

    if (currentBalance <= 0) {
      const debtPaidOffText = this.suggestedDateDisplayTarget.dataset.debtPaidOffText
      this.suggestedDateDisplayTarget.value = debtPaidOffText
      this.replaceButtonTarget.disabled = true
      this.replaceButtonTarget.dataset.suggestedDate = ""
      return
    }

    // Get the payment frequency
    const frequencyField = this.element.querySelector('select[name="debt[payment_frequency]"]')
    const frequency = frequencyField ? frequencyField.value : 'monthly'

    // Simple calculation without interest (backend handles actual interest calculation)
    const periodsNeeded = Math.ceil(currentBalance / paymentAmount)

    // Calculate the suggested date based on frequency
    const suggestedDate = new Date()

    switch(frequency) {
      case 'weekly':
        // Add weeks (7 days per period)
        suggestedDate.setDate(suggestedDate.getDate() + (periodsNeeded * 7))
        break
      case 'biweekly':
        // Add biweekly periods (14 days per period)
        suggestedDate.setDate(suggestedDate.getDate() + (periodsNeeded * 14))
        break
      case 'semimonthly':
        // Add semimonthly periods (15 days per period - twice a month)
        suggestedDate.setDate(suggestedDate.getDate() + (periodsNeeded * 15))
        break
      case 'monthly':
      default:
        // Add months
        suggestedDate.setMonth(suggestedDate.getMonth() + periodsNeeded)
        break
    }

    // Format date for display using the document's locale
    const options = { year: 'numeric', month: 'long', day: 'numeric' }
    const locale = document.documentElement.lang || 'es'
    this.suggestedDateDisplayTarget.value = suggestedDate.toLocaleDateString(locale, options)

    // Store ISO date for replacement (use local date, not UTC)
    const year = suggestedDate.getFullYear()
    const month = String(suggestedDate.getMonth() + 1).padStart(2, '0')
    const day = String(suggestedDate.getDate()).padStart(2, '0')
    const localISODate = `${year}-${month}-${day}`

    this.replaceButtonTarget.disabled = false
    this.replaceButtonTarget.dataset.suggestedDate = localISODate
  }

  // Replace target_payoff_date with suggested date
  replaceDateWithSuggested(event) {
    const button = event.currentTarget
    const suggestedDate = button.dataset.suggestedDate

    if (!suggestedDate || !this.hasTargetDateFieldTarget) return

    this.targetDateFieldTarget.value = suggestedDate

    // Trigger change event to update form state
    this.targetDateFieldTarget.dispatchEvent(new Event("change", { bubbles: true }))

    // Update calculated amount if in calculated mode
    this.updateCalculatedAmount()

    // Show visual feedback
    this.targetDateFieldTarget.classList.add("ring-2", "ring-blue-500")
    setTimeout(() => {
      this.targetDateFieldTarget.classList.remove("ring-2", "ring-blue-500")
    }, 1000)
  }

  // Calculate and update payment amount for Calculated mode (simple calculation without interest)
  updateCalculatedAmount() {
    const mode = this.modeInputTarget.value
    if (mode !== "calculated") return
    if (!this.hasCalculatedAmountValueTarget) return

    // Get values from form
    const currentBalanceField = this.element.querySelector('input[name="debt[current_balance]"]')
    const targetDateField = this.element.querySelector('input[name="debt[target_payoff_date]"]')
    const frequencyField = this.element.querySelector('select[name="debt[payment_frequency]"]')

    if (!currentBalanceField || !targetDateField) return

    // Clean the value by removing $, commas, and whitespace
    const cleanValue = (value) => {
      if (!value || value.trim() === "") return 0
      return parseFloat(value.replace(/[$,\s]/g, "")) || 0
    }

    const currentBalance = cleanValue(currentBalanceField.value)
    const targetDateValue = targetDateField.value
    const frequency = frequencyField ? frequencyField.value : 'monthly'

    // Return 0 if required fields are missing
    if (currentBalance <= 0 || !targetDateValue) {
      this.calculatedAmountValueTarget.textContent = "$0.00"
      return
    }

    if (currentBalance <= 0) {
      this.calculatedAmountValueTarget.textContent = "$0.00"
      return
    }

    // Calculate days until target date
    const targetDate = new Date(targetDateValue)
    const today = new Date()
    const daysRemaining = Math.ceil((targetDate - today) / (1000 * 60 * 60 * 24))

    if (daysRemaining <= 0) {
      // If target date is in the past, show the full remaining balance
      this.calculatedAmountValueTarget.textContent = `$${currentBalance.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`
      return
    }

    // Calculate periods remaining based on frequency
    let periodsRemaining
    switch(frequency) {
      case 'weekly':
        periodsRemaining = Math.ceil(daysRemaining / 7)
        break
      case 'biweekly':
        periodsRemaining = Math.ceil(daysRemaining / 14)
        break
      case 'semimonthly':
        periodsRemaining = Math.ceil(daysRemaining / 15)
        break
      case 'monthly':
      default:
        // Calculate months for monthly frequency
        periodsRemaining = ((targetDate.getFullYear() - today.getFullYear()) * 12) + (targetDate.getMonth() - today.getMonth())
        if (periodsRemaining <= 0) periodsRemaining = 1
        break
    }

    // Simple calculation (backend handles actual interest calculation)
    const paymentAmount = (currentBalance / periodsRemaining).toFixed(2)
    this.calculatedAmountValueTarget.textContent = `$${parseFloat(paymentAmount).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`
  }
}
