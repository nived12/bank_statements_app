import { Controller } from "@hotwired/stimulus"

// Shared base for the goal-contribution and debt-payment "mode" dropdowns.
// The dropdown, label toggling, field visibility, and date/amount math are
// identical between the two forms; subclasses only implement the two hooks
// below to say which form fields to read and how "remaining" is computed:
//
//   computeSuggestedPeriods()   -> for Fixed mode's suggested target date
//   computeCalculatedRemaining() -> for Calculated mode's per-period amount
//
// Not registered as a Stimulus controller itself — ContributionModeController
// and PaymentModeController extend it and are registered in index.js.
export default class ModeController extends Controller {
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
      this.modeSummaryTarget.classList.add("text-slate-900", "dark:text-slate-100")
    } else {
      this.modeSummaryTarget.classList.remove("text-slate-900", "dark:text-slate-100")
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

      // Calculate and display the amount
      this.updateCalculatedAmount()
    }
  }

  // Update the amount label between required and plain
  updateAmountLabel(isRequired) {
    if (!this.hasAmountLabelContainerTarget) return

    const labelText = this.amountLabelContainerTarget.querySelector('label').childNodes[0].textContent.trim()

    if (isRequired) {
      // Show required (red asterisk)
      this.amountLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          ${labelText}
          <span class="text-red-500">*</span>
        </label>
      `
    } else {
      // Show plain label (no asterisk, no optional text)
      this.amountLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          ${labelText}
        </label>
      `
    }
  }

  // Update the target date label between required and optional
  updateTargetDateLabel(isRequired) {
    if (!this.hasTargetDateLabelContainerTarget) return

    // Extract the label text (without asterisk or optional text)
    const labelElement = this.targetDateLabelContainerTarget.querySelector('label')
    if (!labelElement) return

    const labelText = labelElement.childNodes[0].textContent.trim()

    if (isRequired) {
      // Show required (red asterisk)
      this.targetDateLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          ${labelText}
          <span class="text-red-500">*</span>
        </label>
      `
    } else {
      // Show optional
      this.targetDateLabelContainerTarget.innerHTML = `
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          ${labelText}
          <span class="text-slate-400 text-xs font-normal ml-1">(optional)</span>
        </label>
      `
    }
  }

  // Check if target date is present and toggle warning/content visibility
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

  // Calculate and update the suggested target date for Fixed mode
  updateSuggestedDate() {
    const mode = this.modeInputTarget.value
    if (mode !== "fixed") return
    if (!this.hasSuggestedDateDisplayTarget || !this.hasReplaceButtonTarget) return

    const result = this.computeSuggestedPeriods()
    if (result.action === "abort") return

    if (result.action === "message") {
      this.suggestedDateDisplayTarget.value = result.text
      this.replaceButtonTarget.disabled = true
      this.replaceButtonTarget.dataset.suggestedDate = ""
      return
    }

    // action === "date"
    const suggestedDate = this.addPeriods(new Date(), result.periodsNeeded, result.frequency)

    // Format date for display using the document's locale
    const options = { year: 'numeric', month: 'long', day: 'numeric' }
    const locale = document.documentElement.lang || 'es'
    this.suggestedDateDisplayTarget.value = suggestedDate.toLocaleDateString(locale, options)

    this.replaceButtonTarget.disabled = false
    this.replaceButtonTarget.dataset.suggestedDate = this.toISODate(suggestedDate)
  }

  // Replace target date with the suggested date
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

  // Calculate and update the per-period amount for Calculated mode
  updateCalculatedAmount() {
    const mode = this.modeInputTarget.value
    if (mode !== "calculated") return
    if (!this.hasCalculatedAmountValueTarget) return

    const inputs = this.computeCalculatedRemaining()
    if (inputs.action === "abort") return

    if (inputs.action === "zero") {
      this.calculatedAmountValueTarget.textContent = "$0.00"
      return
    }

    // action === "compute"
    const { remaining, targetDateValue, frequency } = inputs
    const targetDate = new Date(targetDateValue)
    const today = new Date()
    const daysRemaining = Math.ceil((targetDate - today) / (1000 * 60 * 60 * 24))

    if (daysRemaining <= 0) {
      // If target date is in the past, show the full remaining amount
      this.calculatedAmountValueTarget.textContent = this.formatMoney(remaining)
      return
    }

    const periodsRemaining = this.periodsRemaining(daysRemaining, frequency, targetDate, today)
    this.calculatedAmountValueTarget.textContent = this.formatMoney(remaining / periodsRemaining)
  }

  // ---- Shared helpers ----

  // Clean a money string by removing $, commas, and whitespace
  cleanValue(value) {
    if (!value || value.trim() === "") return 0
    return parseFloat(value.replace(/[$,\s]/g, "")) || 0
  }

  // Advance a date by N periods of the given frequency
  addPeriods(date, periods, frequency) {
    const result = new Date(date)
    switch (frequency) {
      case 'weekly':
        result.setDate(result.getDate() + (periods * 7))
        break
      case 'biweekly':
        result.setDate(result.getDate() + (periods * 14))
        break
      case 'semimonthly':
        result.setDate(result.getDate() + (periods * 15))
        break
      case 'monthly':
      default:
        result.setMonth(result.getMonth() + periods)
        break
    }
    return result
  }

  // Number of periods between today and the target date for the given frequency
  periodsRemaining(daysRemaining, frequency, targetDate, today) {
    switch (frequency) {
      case 'weekly':
        return Math.ceil(daysRemaining / 7)
      case 'biweekly':
        return Math.ceil(daysRemaining / 14)
      case 'semimonthly':
        return Math.ceil(daysRemaining / 15)
      case 'monthly':
      default: {
        let months = ((targetDate.getFullYear() - today.getFullYear()) * 12) + (targetDate.getMonth() - today.getMonth())
        if (months <= 0) months = 1
        return months
      }
    }
  }

  // Format a date as local (not UTC) YYYY-MM-DD for the hidden replace value
  toISODate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  // Format a number as a $ amount with thousands separators
  formatMoney(amount) {
    return `$${parseFloat(amount).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`
  }

  // ---- Subclass hooks ----

  // Returns one of:
  //   { action: "abort" }                              - required fields not in DOM
  //   { action: "message", text }                      - display text, disable replace
  //   { action: "date", periodsNeeded, frequency }     - compute suggested date
  computeSuggestedPeriods() {
    throw new Error("computeSuggestedPeriods() must be implemented by subclass")
  }

  // Returns one of:
  //   { action: "abort" }                                       - required fields not in DOM
  //   { action: "zero" }                                        - show $0.00
  //   { action: "compute", remaining, targetDateValue, frequency }
  computeCalculatedRemaining() {
    throw new Error("computeCalculatedRemaining() must be implemented by subclass")
  }
}
