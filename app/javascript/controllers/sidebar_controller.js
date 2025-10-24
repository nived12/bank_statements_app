import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
// NOTE: Active state is now handled server-side using controller_name in ERB
// This controller is kept for potential future sidebar interactions
export default class extends Controller {
  connect() {
    // Server-side rendering handles active states via controller_name
    // No JavaScript interference needed
  }
}
