import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  select(event) {
    const button = event.currentTarget
    const color = button.dataset.color

    // Update hidden input
    this.inputTarget.value = color

    // Ring colours are baked into the markup; toggling the width is enough to show them.
    this.buttonTargets.forEach(btn => {
      btn.classList.remove('ring-4', 'ring-offset-2')
      btn.setAttribute('aria-pressed', 'false')
    })

    button.classList.add('ring-4', 'ring-offset-2')
    button.setAttribute('aria-pressed', 'true')
  }
}
