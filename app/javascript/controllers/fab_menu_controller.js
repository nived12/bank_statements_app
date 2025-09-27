import { Controller } from "@hotwired/stimulus"

// FAB Menu Controller - Handles floating action button menu
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.isOpen = false
    // Bind click outside to close
    this.clickOutsideHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this.close()
      }
    }
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    this.menuTarget.classList.remove("opacity-0", "invisible")
    this.menuTarget.classList.add("opacity-100", "visible")

    // Rotate the FAB icon
    const icon = this.element.querySelector(".global-fab-icon")
    if (icon) {
      icon.style.transform = "rotate(45deg)"
    }

    // Add click outside listener
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 10)
  }

  close() {
    this.isOpen = false
    this.menuTarget.classList.remove("opacity-100", "visible")
    this.menuTarget.classList.add("opacity-0", "invisible")

    // Reset the FAB icon
    const icon = this.element.querySelector(".global-fab-icon")
    if (icon) {
      icon.style.transform = "rotate(0deg)"
    }

    document.removeEventListener("click", this.clickOutsideHandler)
  }
}