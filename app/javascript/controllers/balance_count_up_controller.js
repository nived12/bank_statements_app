import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { amount: Number, duration: { type: Number, default: 800 } }

  connect() {
    this.animate()
  }

  animate() {
    const end = this.amountValue
    if (!Number.isFinite(end)) return

    const start = 0
    const duration = this.durationValue
    const startTime = performance.now()

    const step = (now) => {
      const elapsed = now - startTime
      const progress = Math.min(elapsed / duration, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      const current = start + (end - start) * eased
      this.element.textContent = this.format(current)
      if (progress < 1) requestAnimationFrame(step)
    }

    requestAnimationFrame(step)
  }

  format(value) {
    const locale = document.documentElement.lang === "es" ? "es-MX" : "en-US"
    return new Intl.NumberFormat(locale, {
      style: "currency",
      currency: "MXN",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value)
  }
}
