import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._applyTheme(this._resolvedTheme())
  }

  toggle() {
    const current = document.documentElement.getAttribute("data-theme")
    const next = current === "dark" ? "light" : "dark"
    localStorage.setItem("vittio-theme", next)
    this._applyTheme(next)
  }

  _applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    // Update button icon if present
    const icon = this.element.querySelector("[data-dark-mode-target='icon']")
    if (icon) {
      icon.textContent = theme === "dark" ? "☀️" : "🌙"
    }
  }

  _resolvedTheme() {
    const stored = localStorage.getItem("vittio-theme")
    if (stored) return stored
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}
