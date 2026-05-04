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
    const moon = this.element.querySelector("[data-dark-mode-moon]")
    const sun = this.element.querySelector("[data-dark-mode-sun]")
    if (moon) moon.style.display = theme === "dark" ? "none" : ""
    if (sun) sun.style.display = theme === "dark" ? "" : "none"
  }

  _resolvedTheme() {
    const stored = localStorage.getItem("vittio-theme")
    if (stored) return stored
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }
}
