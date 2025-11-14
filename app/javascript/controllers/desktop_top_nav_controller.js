import { Controller } from "@hotwired/stimulus"

// Desktop Top Nav Controller - Handles desktop top nav functionality
export default class extends Controller {
  connect() {
    // Find the scrollable main element
    this.scrollableElement = document.querySelector("main")

    if (this.scrollableElement) {
      // Store bound function so we can remove it later
      this.boundHandleScroll = this.handleScroll.bind(this)
      this.scrollableElement.addEventListener("scroll", this.boundHandleScroll)
    }
  }

  handleScroll() {
    console.log("handleScroll", this.scrollableElement.scrollTop)
    if (this.scrollableElement.scrollTop > 0) {
      this.element.classList.add("scrolled")
    } else {
      this.element.classList.remove("scrolled")
    }
  }

  disconnect() {
    if (this.scrollableElement) {
      this.scrollableElement.removeEventListener("scroll", this.boundHandleScroll)
    }
  }
}