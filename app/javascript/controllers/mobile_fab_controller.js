import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle('show')
  }

  hide() {
    this.menuTarget.classList.remove('show')
  }

  connect() {
    // Hide menu when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.element.contains(e.target)) {
        this.hide()
      }
    })
  }
}
