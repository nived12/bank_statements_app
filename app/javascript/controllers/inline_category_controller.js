import { Controller } from "@hotwired/stimulus"

/**
 * Inline category editing for transaction table rows.
 *
 * The category dropdown markup is rendered ONCE per page (in #shared-category-panel-host)
 * and shared by every row, instead of being duplicated inside each row — which previously
 * ballooned the transactions page to several MB. Each row's controller is just a trigger;
 * the SharedCategoryPanel singleton owns the one panel and routes selections back to whichever
 * row opened it.
 *
 * The panel is moved to <body> when open (portal pattern) so it escapes overflow clipping
 * from the table's scroll containers, then parked back in its host when closed.
 */
const SharedCategoryPanel = {
  active: null,
  panel: null,
  host: null,
  search: null,

  // Resolve (and lazily wire) the singleton panel. Re-resolves after a Turbo render
  // replaces the host with a fresh panel node.
  ensure() {
    if (this.panel && this.panel.isConnected) return this.panel

    const host = document.getElementById("shared-category-panel-host")
    const panel = host?.querySelector("[data-role='category-panel']")
    if (!panel) {
      this.panel = null
      return null
    }

    this.host = host
    this.panel = panel
    this.search = panel.querySelector("[data-role='category-search']")
    panel.addEventListener("click", this._onPanelClick.bind(this))
    if (this.search) {
      this.search.addEventListener("input", () => this.filter())
    }
    return panel
  },

  openFor(controller) {
    const panel = this.ensure()
    if (!panel) return

    this.active = controller
    document.body.appendChild(panel)
    this._position(controller.triggerTarget)
    this._highlight(controller.currentCategoryIdValue)
    panel.style.display = ""

    if (this.search) {
      this.search.value = ""
      this.filter()
      setTimeout(() => this.search.focus(), 50)
    }
  },

  close() {
    if (!this.panel) return
    this.panel.style.display = "none"
    if (this.host) this.host.appendChild(this.panel)
    this.active = null
  },

  isOpenFor(controller) {
    return this.active === controller
  },

  contains(node) {
    return this.panel?.contains(node)
  },

  filter() {
    if (!this.search || !this.panel) return
    const items = this.panel.querySelectorAll("[data-role='category-item']")
    if (!items.length) return

    const query = this.search.value.toLowerCase().trim()

    if (!query) {
      items.forEach(item => item.style.display = "")
      return
    }

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

    items.forEach(item => {
      const name = item.dataset.categoryName?.toLowerCase() || ""
      const isMatch = matchedIds.has(item.dataset.categoryId)
      const isParentOfMatch = matchedParentNames.has(name)
      item.style.display = (isMatch || isParentOfMatch) ? "" : "none"
    })
  },

  _highlight(currentId) {
    if (!this.panel) return
    const id = currentId == null ? "" : String(currentId)
    this.panel.querySelectorAll("[data-category-id]").forEach(item => {
      const selected = (item.dataset.categoryId || "") === id
      item.classList.toggle("bg-blue-50", selected)
      item.classList.toggle("text-blue-700", selected)
    })
  },

  _position(trigger) {
    const triggerRect = trigger.getBoundingClientRect()
    const viewportHeight = window.innerHeight
    const viewportWidth = window.innerWidth
    const panelHeight = 320 // max-h-80
    const panelWidth = 288  // w-72

    let top = triggerRect.bottom + 4
    let left = triggerRect.left

    if (top + panelHeight > viewportHeight - 8) {
      top = viewportHeight - panelHeight - 8
    }
    top = Math.max(8, top)

    if (left + panelWidth > viewportWidth) {
      left = viewportWidth - panelWidth - 8
    }
    left = Math.max(8, left)

    this.panel.style.position = "fixed"
    this.panel.style.top = `${top}px`
    this.panel.style.left = `${left}px`
    this.panel.style.zIndex = "9999"
  },

  _onPanelClick(event) {
    const btn = event.target.closest("[data-category-id]")
    if (!btn || !this.active) return

    event.preventDefault()
    event.stopPropagation()

    const controller = this.active
    const categoryId = btn.dataset.categoryId
    controller.close() // closes panel + removes the row's document listeners
    controller.selectCategory(categoryId)
  },
}

export default class extends Controller {
  static targets = ["trigger"]
  static values = { url: String, currentCategoryId: String }

  connect() {
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    if (SharedCategoryPanel.isOpenFor(this)) {
      SharedCategoryPanel.close()
      this.cleanup()
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (SharedCategoryPanel.isOpenFor(this)) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    SharedCategoryPanel.openFor(this)

    // Add listeners after a short delay to prevent immediate close
    setTimeout(() => {
      document.addEventListener("click", this.boundHandleClickOutside)
      document.addEventListener("keydown", this.boundHandleKeydown)
    }, 10)
  }

  close() {
    SharedCategoryPanel.close()
    this.cleanup()
  }

  cleanup() {
    document.removeEventListener("click", this.boundHandleClickOutside)
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target) && !SharedCategoryPanel.contains(event.target)) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  async selectCategory(categoryId) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

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
