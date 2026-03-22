import { Controller } from "@hotwired/stimulus"
import { visit } from "@hotwired/turbo"

export default class extends Controller {
  static values = {
    url: String,
    currentStatus: String,
    interval: { type: Number, default: 10000 }
  }

  connect() {
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
        visit(window.location.href)
      }
    } catch {
      // Network error — silently retry on next interval
    }
  }
}
