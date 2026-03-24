import { Controller } from "@hotwired/stimulus"

/**
 * Inline category editing for transaction table rows.
 * Shows a dropdown to change a transaction's category without leaving the page.
 * Uses fixed positioning to avoid overflow clipping from parent containers.
 */
export default class extends Controller {
  static targets = ["trigger", "dropdown", "panel", "search", "categoryItem"]
  static values = { url: String }

  connect() {
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    this.cleanup()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.dropdownTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.dropdownTarget.classList.remove("hidden")
    this.positionDropdown()

    // Focus search input
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.filterCategories()
      setTimeout(() => this.searchTarget.focus(), 50)
    }

    // Add listeners after a short delay to prevent immediate close
    setTimeout(() => {
      document.addEventListener("click", this.boundHandleClickOutside)
      document.addEventListener("keydown", this.boundHandleKeydown)
    }, 10)
  }

  close() {
    this.dropdownTarget.classList.add("hidden")
    this.cleanup()
  }

  cleanup() {
    document.removeEventListener("click", this.boundHandleClickOutside)
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  positionDropdown() {
    if (!this.hasPanelTarget) return

    const triggerRect = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const viewportHeight = window.innerHeight
    const viewportWidth = window.innerWidth

    // Position below trigger by default
    let top = triggerRect.bottom + 4
    let left = triggerRect.left

    // Check if dropdown would overflow bottom of viewport
    const panelHeight = 320 // max-h-80 = 20rem = 320px
    if (top + panelHeight > viewportHeight) {
      top = triggerRect.top - panelHeight - 4
    }

    // Check if dropdown would overflow right of viewport
    const panelWidth = 288 // w-72 = 18rem = 288px
    if (left + panelWidth > viewportWidth) {
      left = viewportWidth - panelWidth - 8
    }

    panel.style.top = `${top}px`
    panel.style.left = `${left}px`
  }

  async selectCategory(event) {
    event.preventDefault()
    event.stopPropagation()

    const categoryId = event.currentTarget.dataset.categoryId
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    this.close()

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ category_id: categoryId || null })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Failed to update category:", error)
    }
  }

  filterCategories() {
    if (!this.hasSearchTarget || !this.hasCategoryItemTarget) return

    const query = this.searchTarget.value.toLowerCase().trim()
    const items = this.categoryItemTargets

    if (!query) {
      items.forEach(item => item.style.display = "")
      return
    }

    // Find direct matches
    const matchedIds = new Set()
    const matchedParentNames = new Set()

    items.forEach(item => {
      const name = item.dataset.categoryName?.toLowerCase() || ""
      if (name.includes(query)) {
        matchedIds.add(item.dataset.categoryId)
        const parentName = item.dataset.categoryParentName
        if (parentName) matchedParentNames.add(parentName.toLowerCase())
      }
    })

    // Show matched items and parents of matched children
    items.forEach(item => {
      const name = item.dataset.categoryName?.toLowerCase() || ""
      const isMatch = matchedIds.has(item.dataset.categoryId)
      const isParentOfMatch = matchedParentNames.has(name)

      item.style.display = (isMatch || isParentOfMatch) ? "" : "none"
    })
  }
}
