import { Controller } from "@hotwired/stimulus"

// Goal Selector - Dropdown for manually linking transactions to goals
export default class extends Controller {
  static targets = ["menu", "selectedText", "hiddenInput"]

  connect() {
    // Bind click outside to close
    this.clickOutsideHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle(event) {
    event?.preventDefault()
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    // Add click outside listener after a brief delay
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 10)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  selectGoal(event) {
    event.preventDefault()
    const item = event.currentTarget
    const goalId = item.dataset.goalId
    const goalName = item.dataset.goalName
    const goalStartDate = item.dataset.goalStartDate
    const goalDeadline = item.dataset.goalDeadline

    // Get transaction date from form
    const transactionDateInput = document.querySelector('[data-transaction-form-target="date"]')
    const transactionDate = transactionDateInput ? transactionDateInput.value : null

    // Check if transaction date is within goal's date range
    if (transactionDate && goalStartDate && goalDeadline) {
      const txDate = new Date(transactionDate)
      const startDate = new Date(goalStartDate)
      const endDate = new Date(goalDeadline)

      if (txDate < startDate || txDate > endDate) {
        // Show warning but allow user to proceed
        const warning = this.formatDateWarning(transactionDate, goalStartDate, goalDeadline)
        if (!confirm(warning)) {
          // User cancelled, don't select the goal
          this.close()
          return
        }
      }
    }

    // Update hidden input
    this.hiddenInputTarget.value = goalId

    // Update display
    this.selectedTextTarget.textContent = goalName

    this.close()
  }

  clearSelection(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.hiddenInputTarget.value = ""
    this.selectedTextTarget.textContent = this.selectedTextTarget.dataset.placeholder || "Choose a goal (optional)"
    this.close()
  }

  formatDateWarning(txDate, startDate, endDate) {
    // Get translations if available, otherwise use fallback
    const template = this.element.dataset.goalSelectorWarningTemplate ||
      "⚠️ This transaction date (%{date}) is outside the goal's active period (%{start} to %{end}). Do you still want to link it?"

    return template
      .replace('%{date}', txDate)
      .replace('%{start}', startDate)
      .replace('%{end}', endDate)
  }
}
