import { Controller } from "@hotwired/stimulus"

/**
 * Inline category editing for transaction table rows.
 * Shows a dropdown to change a transaction's category without leaving the page.
 *
 * The panel is moved to document.body when open (portal pattern) so it escapes
 * overflow clipping from the table's scroll containers. Events are bound
 * manually since Stimulus data-actions don't fire outside the controller element.
 */
export default class extends Controller {
  static targets = ["trigger", "dropdown"]
  static values = { url: String }

  connect() {
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this._isOpen = false

    // Cache panel reference — it will be moved to <body> when open
    this._panel = this.dropdownTarget.querySelector("[data-role='category-panel']")
    if (!this._panel) return

    this._search = this._panel.querySelector("[data-role='category-search']")
    this._getItems = () => this._panel.querySelectorAll("[data-role='category-item']")

    // Bind events manually (Stimulus actions won't fire when panel is in <body>)
    this._panel.addEventListener("click", this._onPanelClick.bind(this))
    if (this._search) {
      this._search.addEventListener("input", () => this.filterCategories())
    }
  }

  disconnect() {
    this.cleanup()
    if (this._panel?.parentElement === document.body) {
      this._panel.remove()
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this._isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (!this._panel) return

    // Move panel to body to escape overflow clipping from table containers
    document.body.appendChild(this._panel)
    this._positionPanel()
    this._panel.style.display = ""
    this._isOpen = true

    // Reset search and show all items
    if (this._search) {
      this._search.value = ""
      this.filterCategories()
      setTimeout(() => this._search.focus(), 50)
    }

    // Add listeners after a short delay to prevent immediate close
    setTimeout(() => {
      document.addEventListener("click", this.boundHandleClickOutside)
      document.addEventListener("keydown", this.boundHandleKeydown)
    }, 10)
  }

  close() {
    if (!this._panel) return

    this._panel.style.display = "none"
    this._isOpen = false

    // Move panel back to its parking spot inside the controller element
    this.dropdownTarget.appendChild(this._panel)
    this.cleanup()
  }

  cleanup() {
    document.removeEventListener("click", this.boundHandleClickOutside)
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target) && !this._panel?.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  filterCategories() {
    if (!this._search) return
    const items = this._getItems()
    if (!items.length) return

    const query = this._search.value.toLowerCase().trim()

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

  // --- private ---

  _positionPanel() {
    const triggerRect = this.triggerTarget.getBoundingClientRect()
    const viewportHeight = window.innerHeight
    const viewportWidth = window.innerWidth
    const panelHeight = 320 // max-h-80
    const panelWidth = 288  // w-72

    // Default: below the trigger
    let top = triggerRect.bottom + 4
    let left = triggerRect.left

    // If panel overflows bottom, slide it up just enough to fit
    if (top + panelHeight > viewportHeight - 8) {
      top = viewportHeight - panelHeight - 8
    }
    top = Math.max(8, top)

    // Right-edge clamp
    if (left + panelWidth > viewportWidth) {
      left = viewportWidth - panelWidth - 8
    }
    left = Math.max(8, left)

    this._panel.style.position = "fixed"
    this._panel.style.top = `${top}px`
    this._panel.style.left = `${left}px`
    this._panel.style.zIndex = "9999"
  }

  _onPanelClick(event) {
    const btn = event.target.closest("[data-category-id]")
    if (!btn) return

    event.preventDefault()
    event.stopPropagation()
    this._selectCategory(btn.dataset.categoryId)
  }

  async _selectCategory(categoryId) {
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
}
