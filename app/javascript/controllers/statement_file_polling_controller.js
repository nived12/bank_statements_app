import { Controller } from "@hotwired/stimulus"
import { visit } from "@hotwired/turbo"

export default class extends Controller {
  static values = {
    url: String,
    currentStatus: String,
    interval: { type: Number, default: 5000 }
  }

  static terminalStatuses = ["completed", "failed", "error"]

  connect() {
    if (this.constructor.terminalStatuses.includes(this.currentStatusValue)) return
    this.pollingTimer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.pollingTimer)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      if (data.status !== this.currentStatusValue) {
        clearInterval(this.pollingTimer)
        const frame = this.element.closest("turbo-frame")
        if (frame) {
          frame.src = window.location.href
        } else {
          visit(window.location.href)
        }
      }
    } catch {
      // Network error — silently retry on next interval
    }
  }
}
