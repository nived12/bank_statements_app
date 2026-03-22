import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  show(event) {
    event.preventDefault()
    event.stopPropagation()
    this.modalTarget.classList.remove("hidden")
  }

  hide() {
    this.modalTarget.classList.add("hidden")
  }

  backdropClick(event) {
    if (event.target === event.currentTarget) this.hide()
  }
}
