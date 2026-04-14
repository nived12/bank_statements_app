import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 3000 }
  }

  connect() {
    this.poll()
  }

  disconnect() {
    this.stopPolling()
  }

  poll() {
    this.timer = setInterval(() => {
      this.checkStatus()
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return

      const data = await response.json()

      if (data.sync_status === "synced" || data.sync_status === "error") {
        this.stopPolling()
        // Reload the page to show updated data
        window.location.reload()
      }
    } catch (_error) {
      // Silently fail, will retry on next interval
    }
  }
}
