import { Controller } from "@hotwired/stimulus"

const LONG_PRESS_MS = 450

export default class extends Controller {
  static targets = ["dial", "backdrop", "fabLink"]
  static values = {
    open: { type: Boolean, default: false },
    newTransactionPath: String,
    uploadPath: String,
    assistantPath: String
  }

  connect() {
    this.pressTimer = null
    this.longPressTriggered = false
    this.escapeHandler = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    this.clearPressTimer()
    document.removeEventListener("keydown", this.escapeHandler)
  }

  pointerDown(event) {
    if (event.button !== 0) return
    this.longPressTriggered = false
    this.clearPressTimer()
    this.pressTimer = window.setTimeout(() => {
      this.longPressTriggered = true
      event.preventDefault()
      this.open()
    }, LONG_PRESS_MS)
  }

  pointerUp(event) {
    this.clearPressTimer()
    if (this.longPressTriggered) {
      event.preventDefault()
    }
  }

  click(event) {
    if (this.longPressTriggered || this.openValue) {
      event.preventDefault()
      this.longPressTriggered = false
    }
  }

  pointerLeave() {
    this.clearPressTimer()
  }

  contextMenu(event) {
    event.preventDefault()
    this.open()
  }

  open() {
    if (this.openValue) return
    this.openValue = true
    this.dialTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.dialTarget.classList.add("open")
      this.backdropTarget.classList.add("open")
    })
    document.addEventListener("keydown", this.escapeHandler)
  }

  close() {
    if (!this.openValue) return
    this.openValue = false
    this.dialTarget.classList.remove("open")
    this.backdropTarget.classList.remove("open")
    window.setTimeout(() => {
      if (!this.openValue) {
        this.dialTarget.classList.add("hidden")
        this.backdropTarget.classList.add("hidden")
      }
    }, 200)
    document.removeEventListener("keydown", this.escapeHandler)
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  navigate(event) {
    event.preventDefault()
    const url = event.currentTarget.href
    this.close()
    window.setTimeout(() => {
      window.location.href = url
    }, 190)
  }

  clearPressTimer() {
    if (this.pressTimer) {
      window.clearTimeout(this.pressTimer)
      this.pressTimer = null
    }
  }
}
