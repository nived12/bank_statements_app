import { Controller } from "@hotwired/stimulus"

// Mobile Menu Controller - Handles hamburger menu functionality
export default class extends Controller {
  static targets = ["overlay", "panel"]

  connect() {
    // Bind escape key to close menu
    this.escapeHandler = (event) => {
      if (event.key === "Escape") {
        this.close()
      }
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }

  toggle() {
    if (this.overlayTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Show overlay
    this.overlayTarget.classList.remove("hidden")

    // Slide in panel
    requestAnimationFrame(() => {
      this.panelTarget.classList.remove("-translate-x-full")
      this.panelTarget.classList.add("translate-x-0")
    })

    // Prevent body scroll
    document.body.style.overflow = "hidden"

    // Listen for escape key
    document.addEventListener("keydown", this.escapeHandler)
  }

  close() {
    // Slide out panel
    this.panelTarget.classList.remove("translate-x-0")
    this.panelTarget.classList.add("-translate-x-full")

    // Hide overlay after animation
    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
    }, 300)

    // Restore body scroll
    document.body.style.overflow = ""

    // Remove escape key listener
    document.removeEventListener("keydown", this.escapeHandler)
  }
}
