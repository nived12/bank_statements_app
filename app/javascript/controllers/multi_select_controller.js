import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="multi-select"
export default class extends Controller {
  static targets = ["container", "button", "selectAllButton", "checkbox", "summary"]

  connect() {
    this.updateSummary()
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.containerTarget.classList.contains("hidden")

    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.containerTarget.classList.remove("hidden")
    this.buttonTarget.querySelector("svg").classList.add("rotate-180")
    // Add click outside listener after a short delay to prevent immediate close
    setTimeout(() => {
      document.addEventListener("click", this.boundHandleClickOutside)
    }, 100)
  }

  close() {
    this.containerTarget.classList.add("hidden")
    this.buttonTarget.querySelector("svg").classList.remove("rotate-180")
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  handleClickOutside(event) {
    // Check if click is outside the entire multi-select component
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  toggleAll(event) {
    event.stopPropagation()
    const checkboxes = this.checkboxTargets
    const allChecked = checkboxes.every(cb => cb.checked)

    checkboxes.forEach(cb => {
      cb.checked = !allChecked
    })

    this.updateSummary()
    this.updateSelectAllButton()
  }

  updateCount() {
    this.updateSummary()
    this.updateSelectAllButton()
  }

  updateSummary() {
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked).length
    const totalCount = this.checkboxTargets.length

    if (checkedCount === 0) {
      this.summaryTarget.textContent = this.summaryTarget.dataset.placeholder
      this.summaryTarget.classList.add("text-slate-400")
      this.summaryTarget.classList.remove("text-slate-900")
    } else {
      this.summaryTarget.textContent = `${checkedCount} selected`
      this.summaryTarget.classList.remove("text-slate-400")
      this.summaryTarget.classList.add("text-slate-900")
    }
  }

  updateSelectAllButton() {
    const checkboxes = this.checkboxTargets
    const allChecked = checkboxes.every(cb => cb.checked)

    if (allChecked) {
      this.selectAllButtonTarget.textContent = this.selectAllButtonTarget.dataset.unselectText || "Unselect all"
    } else {
      this.selectAllButtonTarget.textContent = this.selectAllButtonTarget.dataset.selectText || "Select all"
    }
  }
}
