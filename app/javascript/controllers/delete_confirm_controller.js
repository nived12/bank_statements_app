import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "count"]

  show(event) {
    event.preventDefault()
    event.stopPropagation()
    const { path, count } = event.params
    this.formTarget.action = path
    this.countTarget.textContent = count
    this.modalTarget.classList.remove("hidden")
  }

  hide() {
    this.modalTarget.classList.add("hidden")
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) this.hide()
  }
}
