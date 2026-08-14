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
        // Full visit, not a frame reload. The status badge in the page header sits
        // outside this frame, so refreshing only the frame left it showing the value
        // from page load — a failed statement kept reading "Procesando" above a panel
        // that already said processing had failed.
        visit(window.location.href)
      }
    } catch {
      // Network error — silently retry on next interval
    }
  }
}
