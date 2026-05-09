import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "submit"]

  connect() {
    this.updateSubmit()
  }

  checkboxChanged() {
    this.updateSubmit()
  }

  updateSubmit() {
    const allChecked = this.checkboxTargets.every((cb) => cb.checked)
    this.submitTarget.disabled = !allChecked
  }
}
