import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  select(event) {
    const button = event.currentTarget
    const color = button.dataset.color

    // Update hidden input
    this.inputTarget.value = color

    // Remove selection from all buttons
    this.buttonTargets.forEach(btn => {
      btn.classList.remove('ring-4', 'ring-offset-2')
    })

    // Add selection to clicked button
    button.classList.add('ring-4', 'ring-offset-2')
  }
}
