import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "addButton"]
  static values = {
    tab: { type: String, default: "savings" },
    savingsPath: String,
    debtsPath: String,
    goalsPath: String
  }

  connect() {
    this.show(this.tabValue)
  }

  select(event) {
    const tab = event.currentTarget.dataset.tab
    this.tabValue = tab
    this.show(tab)
  }

  show(tab) {
    this.tabTargets.forEach((el) => {
      el.classList.toggle("active", el.dataset.tab === tab)
    })
    this.panelTargets.forEach((el) => {
      el.classList.toggle("hidden", el.dataset.tab !== tab)
    })
    if (this.hasAddButtonTarget) {
      const paths = {
        savings: this.savingsPathValue,
        debts: this.debtsPathValue,
        goals: this.goalsPathValue
      }
      this.addButtonTarget.href = paths[tab] || this.savingsPathValue
    }
  }
}
