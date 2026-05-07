import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["moon", "sun"]

  connect() {
    this._syncIcons(this._resolvedTheme())
  }

  toggle() {
    const current = document.documentElement.getAttribute("data-theme")
    const next = current === "dark" ? "light" : "dark"
    localStorage.setItem("vittio-theme", next)
    document.documentElement.setAttribute("data-theme", next)
    this._syncIcons(next)
    window.dispatchEvent(new CustomEvent("darkModeToggled", { detail: { theme: next } }))
  }

  _syncIcons(theme) {
    if (this.hasMoonTarget) this.moonTarget.style.display = theme === "dark" ? "none" : ""
    if (this.hasSunTarget) this.sunTarget.style.display = theme === "dark" ? "" : "none"
  }

  _resolvedTheme() {
    const stored = localStorage.getItem("vittio-theme")
    if (stored) return stored
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}
