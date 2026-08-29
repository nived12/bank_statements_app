import BaseFormController from "./base_form_controller"
import { CurrencyFormatter } from "../utilities/currency_formatter"

/**
 * Goal form controller.
 * Extends BaseFormController with currency formatting and goal-specific functionality.
 */
export default class extends BaseFormController {
  static targets = [
    "form",
    "submitButton",
    "goalType",
    "targetAmount",
    "startingDebtAmount",
    "debtStrategyField",
    "iconInput",
    "autoLinkCheckbox",
    "autoLinkFields",
    "advancedSettings",
    "advancedSettingsToggle",
    "advancedSettingsContent",
    "radioGroup"
  ]

  connect() {
    // Call parent connect to set up form validation
    super.connect()

    // Initialize on page load
    this.handleGoalTypeChange()

    // Format any existing values with commas
    this.formatExistingValues()

    // Add form submission handler to strip commas
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', (e) => this.stripCommasOnSubmit(e))
    }

    // Add event listeners for bank account and goal type changes
    this.addEventListeners()

    // Set default calculation settings if advanced settings are visible
    setTimeout(() => {
      if (this.hasAdvancedSettingsContentTarget && !this.advancedSettingsContentTarget.classList.contains('hidden')) {
        this.setDefaultCalculationSettings()
      }
    }, 200)
  }

  /**
   * Returns the resource path for goals.
   * @returns {string} The resource path
   */
  getResourcePath() {
    return '/goals'
  }

  addEventListeners() {
    // No need for event listeners since we're using simplified defaults
    // The defaults will be applied when advanced settings are shown
  }

  // Format existing values on page load
  formatExistingValues() {
    if (this.hasTargetAmountTarget && this.targetAmountTarget.value) {
      const value = parseFloat(CurrencyFormatter.stripCommas(this.targetAmountTarget.value))
      if (!isNaN(value)) {
        this.targetAmountTarget.value = CurrencyFormatter.formatWithCommas(value.toFixed(2))
      }
    }

    if (this.hasStartingDebtAmountTarget && this.startingDebtAmountTarget.value) {
      const value = parseFloat(CurrencyFormatter.stripCommas(this.startingDebtAmountTarget.value))
      if (!isNaN(value)) {
        this.startingDebtAmountTarget.value = CurrencyFormatter.formatWithCommas(value.toFixed(2))
      }
    }
  }

  // Strip commas from all amount fields before form submission
  stripCommasOnSubmit(event) {
    if (this.hasTargetAmountTarget && this.targetAmountTarget.value) {
      this.targetAmountTarget.value = CurrencyFormatter.stripCommas(this.targetAmountTarget.value)
    }

    if (this.hasStartingDebtAmountTarget && this.startingDebtAmountTarget.value) {
      this.startingDebtAmountTarget.value = CurrencyFormatter.stripCommas(this.startingDebtAmountTarget.value)
    }
  }

  // Toggle debt-specific fields based on goal type
  toggleDebtFields() {
    if (!this.hasDebtStrategyFieldTarget) return

    const goalType = this.hasGoalTypeTarget ? this.goalTypeTarget.value : ""

    this.debtStrategyFieldTarget.classList.toggle("hidden", goalType !== "debt_payoff")
  }

  // Handle goal type change to set default values
  handleGoalTypeChange() {
    if (!this.hasGoalTypeTarget || !this.hasTargetAmountTarget) return

    const goalType = this.goalTypeTarget.value

    // For debt payoff goals, set target_amount to 0.00 if empty
    if (goalType === "debt_payoff") {
      if (!this.targetAmountTarget.value || this.targetAmountTarget.value === "") {
        this.targetAmountTarget.value = "0.00"
      }
    }
  }

  // Toggle auto-link fields based on checkbox
  toggleAutoLinkFields() {
    const checked = this.autoLinkCheckboxTarget.checked
    
    if (this.hasAutoLinkFieldsTarget) {
      if (checked) {
        this.autoLinkFieldsTarget.classList.remove('hidden')
        if (this.hasAdvancedSettingsTarget) {
          this.advancedSettingsTarget.classList.remove('hidden')
        }
      } else {
        this.autoLinkFieldsTarget.classList.add('hidden')
        if (this.hasAdvancedSettingsTarget) {
          this.advancedSettingsTarget.classList.add('hidden')
        }
        // Hide advanced settings content when auto-link is disabled
        if (this.hasAdvancedSettingsContentTarget) {
          this.advancedSettingsContentTarget.classList.add('hidden')
        }
      }
    }
  }

  // Toggle advanced settings visibility
  toggleAdvancedSettings() {
    if (this.hasAdvancedSettingsContentTarget) {
      this.advancedSettingsContentTarget.classList.toggle('hidden')
      
      // Update button text
      const button = this.advancedSettingsToggleTarget
      const isHidden = this.advancedSettingsContentTarget.classList.contains('hidden')
      button.textContent = isHidden ? 
        this.getTranslation('goals.show_advanced_settings') : 
        this.getTranslation('goals.hide_advanced_settings')
      
      // Set defaults when showing advanced settings for the first time
      if (!isHidden) {
        setTimeout(() => {
          this.setDefaultCalculationSettings()
        }, 100)
      }
    }
  }

  // Update calculation settings when radio buttons change
  updateCalculationSettings(event) {
    // Radio buttons handle their own state, no additional logic needed
    // This method is kept for potential future enhancements
  }

  // Set default radio button selections based on bank account type and goal type
  setDefaultCalculationSettings() {
    if (!this.hasRadioGroupTargets) return

    // Use simplified defaults regardless of account type or goal type
    const defaults = this.getDefaultSettings()
    
    // Set radio button selections
    this.radioGroupTargets.forEach(group => {
      const txType = group.dataset.txType
      const defaultSetting = defaults[txType]
      
      if (defaultSetting) {
        const radioButton = group.querySelector(`input[value="${defaultSetting}"]`)
        if (radioButton) {
          radioButton.checked = true
        }
      }
    })
  }

  // Get default settings - simplified version
  getDefaultSettings() {
    // Simplified defaults as requested
    return {
      'income': 'positive',
      'transfer_in': 'positive', 
      'transfer_out': 'ignore',
      'expense': 'ignore'
    }
  }

  // Helper method to get translations
  getTranslation(key) {
    // Get translations from meta tags or use fallbacks
    const metaTag = document.querySelector(`meta[name="${key}"]`)
    if (metaTag) {
      return metaTag.content
    }
    
    // Fallback translations
    const translations = {
      'goals.show_advanced_settings': 'Show Advanced Settings',
      'goals.hide_advanced_settings': 'Hide Advanced Settings'
    }
    return translations[key] || key
  }

  // Enforce maximum 2 decimal places during input
  enforceDecimalPlaces(event) {
    const input = event.target
    let value = input.value

    // Remove any non-numeric characters except decimal point and commas
    value = value.replace(/[^0-9.,]/g, "")

    // Remove all commas for processing
    value = value.replace(/,/g, "")

    // Only allow one decimal point
    const parts = value.split(".")
    if (parts.length > 2) {
      value = parts[0] + "." + parts.slice(1).join("")
    }

    // Limit to 2 decimal places
    if (parts.length === 2 && parts[1].length > 2) {
      value = parts[0] + "." + parts[1].substring(0, 2)
    }

    input.value = value
  }

  // Format to always show 2 decimal places with comma separators when user leaves the field
  formatDecimal(event) {
    const input = event.target
    let value = input.value

    // Only format if there's a value
    if (!value || value === "") {
      return
    }

    // Remove commas for parsing
    value = value.replace(/,/g, "")

    // Parse the value as a float
    const numValue = parseFloat(value)

    // Check if it's a valid number
    if (isNaN(numValue)) {
      input.value = ""
      return
    }

    // Format to 2 decimal places with comma separators
    input.value = CurrencyFormatter.formatWithCommas(numValue.toFixed(2))
  }


  // Handle icon changed event
  iconChanged() {
    this.checkChanges()
  }

  // Note: checkChanges() and submit() are inherited from BaseFormController
}
