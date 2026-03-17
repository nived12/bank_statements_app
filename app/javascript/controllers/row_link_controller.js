import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Makes a table row clickable as a link.
// Skips navigation when the click target is an interactive element
// (button, link, or their children) so action buttons still work.
export default class extends Controller {
  static values = { url: String }

  visit(event) {
    // Don't navigate if clicking on an interactive element (buttons, links, inputs)
    const interactive = event.target.closest("a, button, input, select, textarea, [data-action]")
    if (interactive && interactive !== this.element) return

    Turbo.visit(this.urlValue)
  }
}
