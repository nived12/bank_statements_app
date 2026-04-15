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

    if (window.scrollY > 50) {
      this.navTarget.classList.add("bg-white/90", "backdrop-blur-md", "shadow-sm")
      this.navTarget.classList.remove("bg-transparent")
    } else {
      this.navTarget.classList.remove("bg-white/90", "backdrop-blur-md", "shadow-sm")
      this.navTarget.classList.add("bg-transparent")
    }
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
