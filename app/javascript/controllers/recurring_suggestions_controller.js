import { Controller } from "@hotwired/stimulus"

/**
 * Recurring suggestions banner on the dashboard.
 *
 * Fetches /transactions/recurring_suggestions on connect.
 * If ≥1 result and not dismissed in the last 7 days → shows banner.
 * Dismiss stores timestamp in localStorage for 7 days.
 */
export default class extends Controller {
  static targets = ["banner", "count", "sheet", "sheetList"]
  static values  = { url: { type: String, default: "/transactions/recurring_suggestions" } }

  DISMISS_KEY = "recurring_banner_dismissed_at"
  DISMISS_TTL = 7 * 24 * 60 * 60 * 1000 // 7 days in ms

  async connect() {
    if (this._isDismissed()) return

    try {
      const res  = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      const data = await res.json()
      if (!Array.isArray(data) || data.length === 0) return

      this._suggestions = data
      if (this.hasCountTarget) this.countTarget.textContent = data.length
      if (this.hasBannerTarget) this.bannerTarget.classList.remove("hidden")
    } catch {
      // Fetch errors are silent
    }
  }

  dismiss() {
    localStorage.setItem(this.DISMISS_KEY, Date.now().toString())
    if (this.hasBannerTarget) this.bannerTarget.classList.add("hidden")
  }

  openSheet() {
    if (!this._suggestions?.length) return
    this._renderSheet(this._suggestions)
    if (this.hasSheetTarget) this.sheetTarget.classList.remove("hidden")
  }

  closeSheet() {
    if (this.hasSheetTarget) this.sheetTarget.classList.add("hidden")
  }

  _isDismissed() {
    const ts = localStorage.getItem(this.DISMISS_KEY)
    if (!ts) return false
    return Date.now() - parseInt(ts, 10) < this.DISMISS_TTL
  }

  _renderSheet(suggestions) {
    if (!this.hasSheetListTarget) return
    this.sheetListTarget.innerHTML = suggestions.map(s => {
      const amount   = new Intl.NumberFormat("es-MX", { style: "currency", currency: "MXN" }).format(s.amount)
      const lastDate = s.last_seen ? new Date(s.last_seen + "T00:00:00").toLocaleDateString("es-MX", { day: "numeric", month: "short" }) : ""
      const letter   = (s.merchant || "?")[0].toUpperCase()
      return `
        <div class="flex items-center gap-3 p-3 border border-slate-100 rounded-xl">
          <div class="w-10 h-10 rounded-full bg-indigo-600 flex items-center justify-center text-white font-semibold flex-shrink-0">${letter}</div>
          <div class="flex-1 min-w-0">
            <p class="font-medium text-slate-900 truncate">${this._esc(s.merchant)}</p>
            <p class="text-sm text-slate-500">${amount} · Último: ${lastDate}</p>
          </div>
          <a href="/transactions/new?prefill_merchant=${encodeURIComponent(s.merchant)}&prefill_amount=${s.amount}&prefill_type=variable_expense"
             class="flex-shrink-0 px-3 py-1.5 text-sm font-medium text-indigo-600 border border-indigo-300 rounded-lg hover:bg-indigo-50 transition-colors">
            Agregar
          </a>
        </div>
      `
    }).join("")
  }

  _esc(str) {
    return (str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
}
