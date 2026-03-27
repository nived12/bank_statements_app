import { Controller } from "@hotwired/stimulus"

/**
 * Handles the active toggle for category rules.
 * Sends a PATCH request when the checkbox state changes.
 */
export default class extends Controller {
  static targets = ["checkbox"]
  static values = { url: String }

  async toggle() {
    const active = this.checkboxTarget.checked
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ category_rule: { active: active } })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        // Revert checkbox on failure
        this.checkboxTarget.checked = !active
      }
    } catch (error) {
      console.error("Failed to toggle active:", error)
      this.checkboxTarget.checked = !active
    }
  }
}
