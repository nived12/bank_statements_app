import { Controller } from "@hotwired/stimulus"

/**
 * PDF report download controller.
 * Shows a small month/year picker panel and triggers a browser download
 * by navigating to the web reports endpoint.
 */
export default class extends Controller {
  static targets = ["panel", "yearSelect", "monthSelect"]
  static values = { baseUrl: { type: String, default: "/reports/monthly" } }

  connect() {
    this._boundClose = this._closeOnOutsideClick.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.panelTarget.classList.contains("hidden")) {
      this._open()
    } else {
      this._close()
    }
  }

  download(event) {
    event.preventDefault()
    const year  = this.yearSelectTarget.value
    const month = this.monthSelectTarget.value
    if (!year || !month) return
    this._triggerDownload(year, month)
    this._close()
  }

  // Downloads using the dashboard's month-selector — no secondary picker needed.
  downloadFromDashboard(event) {
    event.preventDefault()
    const selector = document.getElementById("month-selector") || document.getElementById("month-selector-mobile")
    if (!selector) return
    const [year, month] = selector.value.split("-")
    this._triggerDownload(year, parseInt(month, 10))
  }

  // --- private ---

  _triggerDownload(year, month) {
    const url = `${this.baseUrlValue}?year=${year}&month=${month}`
    const link = document.createElement("a")
    link.href = url
    link.download = `vittio-reporte-${year}-${String(month).padStart(2, "0")}.pdf`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  _open() {
    this.panelTarget.classList.remove("hidden")
    document.addEventListener("click", this._boundClose)
  }

  _close() {
    this.panelTarget.classList.add("hidden")
    document.removeEventListener("click", this._boundClose)
  }

  _closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this._close()
    }
  }
}
