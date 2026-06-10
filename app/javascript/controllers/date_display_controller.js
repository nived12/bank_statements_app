import { Controller } from "@hotwired/stimulus"

// Formats a hidden date input (YYYY-MM-DD) as a human-readable label.
// Used by the mobile transaction / bank-account form picker rows.
export default class extends Controller {
  static targets = ["input", "text"]

  connect() {
    if (this.hasInputTarget && this.inputTarget.value) {
      this._render(this.inputTarget.value)
    }
  }

  update(event) {
    this._render(event.target.value)
  }

  // Fallback when label[for] is not used (e.g. custom row markup). Do not call preventDefault —
  // that blocks native label→input activation on mobile browsers.
  openPicker(event) {
    if (!this.hasInputTarget) return
    if (event.target === this.inputTarget) return

    if (typeof this.inputTarget.showPicker === "function") {
      try {
        this.inputTarget.showPicker()
        return
      } catch {
        // Safari may throw if not triggered from a direct user gesture on the input.
      }
    }

    this.inputTarget.focus({ preventScroll: true })
    this.inputTarget.click()
  }

  _render(isoDate) {
    if (!isoDate || !this.hasTextTarget) return
    try {
      // Parse without timezone shift: split "YYYY-MM-DD" directly
      const [year, month, day] = isoDate.split("-").map(Number)
      const d = new Date(year, month - 1, day)
      const formatted = d.toLocaleDateString("es-MX", {
        day: "numeric",
        month: "long",
        year: "numeric",
      })
      this.textTarget.textContent = formatted
    } catch {
      // leave existing text
    }
  }
}
