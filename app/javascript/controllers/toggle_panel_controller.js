import { Controller } from "@hotwired/stimulus"

/**
 * Simple controller to toggle visibility of a panel by ID.
 */
export default class extends Controller {
  static values = { target: String }

  toggle() {
    const panel = document.getElementById(this.targetValue)
    if (panel) {
      panel.classList.toggle("hidden")
    }
  }
}
