import { Controller } from "@hotwired/stimulus"

// Mobile web uses instant view changes (no slide animations).
export default class extends Controller {
  navigateBack(_event) {
    // No-op: navigation proceeds without transition classes
  }

  goBack(event) {
    event.preventDefault()
    window.history.back()
  }
}
