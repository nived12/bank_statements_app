import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "option"]
  static values = { selected: String, dashboardPath: { type: String, default: "/dashboard" } }

  connect() {
    this.escapeHandler = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }

  open() {
    this.overlayTarget.classList.add("open")
    requestAnimationFrame(() => {
      this.panelTarget.classList.add("open")
    })
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.escapeHandler)
  }

  close() {
    this.panelTarget.classList.remove("open")
    this.overlayTarget.classList.remove("open")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.escapeHandler)
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  select(event) {
    const month = event.currentTarget.dataset.month
    if (!month) return

    this.dispatch("selected", { detail: { month }, bubbles: true })
    this.close()
  }

  visitMonth(event) {
    const { month } = event.detail
    if (!month) return

    const url = `${this.dashboardPathValue}?month=${encodeURIComponent(month)}`
    if (window.Turbo) {
      window.Turbo.visit(url)
    } else {
      window.location.assign(url)
    }
  }
}
