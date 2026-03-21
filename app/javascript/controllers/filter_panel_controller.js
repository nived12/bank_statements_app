import { Controller } from "@hotwired/stimulus"

// Collapsible "Filters" dropdown panel for the desktop transaction filter bar.
export default class extends Controller {
  static targets = ["panel", "badge"]
  static values = { dateActive: Boolean }

  connect() {
    this.boundCloseOnOutside = this.closeOnOutside.bind(this)
    document.addEventListener("click", this.boundCloseOnOutside)
    this.updateBadge()
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnOutside)
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  updateBadge() {
    const count = this.countActiveFilters()
    if (this.hasBadgeTarget) {
      if (count > 0) {
        this.badgeTarget.textContent = count
        this.badgeTarget.classList.remove("hidden")
      } else {
        this.badgeTarget.classList.add("hidden")
      }
    }
  }

  countActiveFilters() {
    const panel = this.panelTarget
    let count = 0

    // Count active selects (non-empty values)
    panel.querySelectorAll("select").forEach(select => {
      if (select.value) count++
    })

    // Count active radio buttons (non-empty values, excluding the "all" option)
    const checkedRadio = panel.querySelector("input[type=radio]:checked")
    if (checkedRadio && checkedRadio.value) count++

    // Count checked category checkboxes as one filter unit
    const checkedCategories = panel.querySelectorAll("input[name=\"category_ids[]\"]:checked")
    if (checkedCategories.length > 0) count++

    // Count active date range (set server-side, updated via value)
    if (this.dateActiveValue) count++

    return count
  }

  // Called when any filter inside the panel changes — update badge then submit
  filterChanged() {
    this.updateBadge()
  }
}
