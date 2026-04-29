import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "mobileMenu", "menuButton", "menuIconOpen", "menuIconClose"]

  connect() {
    this.scrollHandler = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.scrollHandler, { passive: true })
    this.handleScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollHandler)
  }

  handleScroll() {
    if (!this.hasNavTarget) return

    this.navTarget.classList.add("bg-white", "shadow-sm")
    this.navTarget.classList.remove("bg-transparent", "bg-white/90", "backdrop-blur-md")
  }

  toggleMobile() {
    if (!this.hasMobileMenuTarget) return

    const isHidden = this.mobileMenuTarget.classList.contains("hidden")
    this.mobileMenuTarget.classList.toggle("hidden")

    if (this.hasMenuIconOpenTarget && this.hasMenuIconCloseTarget) {
      this.menuIconOpenTarget.classList.toggle("hidden", isHidden)
      this.menuIconCloseTarget.classList.toggle("hidden", !isHidden)
    }
  }

  scrollToSection(event) {
    event.preventDefault()
    const href = event.currentTarget.getAttribute("href")
    const target = document.querySelector(href)
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "center" })

      // Close mobile menu if open
      if (this.hasMobileMenuTarget && !this.mobileMenuTarget.classList.contains("hidden")) {
        this.toggleMobile()
      }
    }
  }
}
