import { Controller } from "@hotwired/stimulus"

// Dropdown Controller - Handles dropdown menu functionality
export default class extends Controller {
  static targets = ["menu"]

  connect() {
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
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    // Add click outside listener
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 10)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.clickOutsideHandler)
  }
}