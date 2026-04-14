import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section"]

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("animate-fade-in-up")
            this.observer.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.1, rootMargin: "0px 0px -50px 0px" }
    )

    this.sectionTargets.forEach((section) => {
      section.style.opacity = "0"
      section.style.transform = "translateY(1.5rem)"
      this.observer.observe(section)
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
