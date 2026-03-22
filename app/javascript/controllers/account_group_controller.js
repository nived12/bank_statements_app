import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chevron"]

  toggle() {
    this.element.classList.toggle("sf-collapsed")
    this.chevronTarget.classList.toggle("rotate-180")
  }
}
