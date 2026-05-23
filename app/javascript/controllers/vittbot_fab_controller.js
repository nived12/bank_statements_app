import { Controller } from "@hotwired/stimulus"

// VITTBOT AI floating chat widget.
// - toggle() flips the panel open/closed (FAB acts as both opener and closer)
// - First open lazy-loads /assistant?layout=compact into the turbo-frame
// - No body-scroll lock and no scrim: the page behind stays interactive,
//   so the user can ask questions about whatever's on screen
// - Escape closes the panel when open
export default class extends Controller {
  static targets = ["panel", "frame", "fab", "historyPanel"]
  static values  = {
    src:  { type: String,  default: "/assistant?layout=compact" },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.boundKey = this.handleKey.bind(this)
    document.addEventListener("keydown", this.boundKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKey)
  }

  toggle() {
    this.openValue ? this.close() : this.open()
  }

  open() {
    if (this.hasFrameTarget && !this.frameTarget.getAttribute("src")) {
      this.frameTarget.setAttribute("src", this.srcValue)
    }
    this.panelTarget.classList.remove("hidden")
    this.openValue = true
    if (this.hasFabTarget) this.fabTarget.setAttribute("aria-expanded", "true")
    requestAnimationFrame(() => {
      this.panelTarget.querySelector("textarea")?.focus()
    })
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.openValue = false
    if (this.hasFabTarget) this.fabTarget.setAttribute("aria-expanded", "false")
  }

  toggleHistory() {
    if (!this.hasHistoryPanelTarget) return
    this.historyPanelTarget.classList.toggle("hidden")
  }

  closeHistory() {
    if (!this.hasHistoryPanelTarget) return
    this.historyPanelTarget.classList.add("hidden")
  }

  handleKey(event) {
    if (event.key !== "Escape") return
    if (!this.openValue) return
    if (this.hasHistoryPanelTarget && !this.historyPanelTarget.classList.contains("hidden")) {
      this.closeHistory()
      return
    }
    this.close()
  }
}
