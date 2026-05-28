import { Controller } from "@hotwired/stimulus"

/**
 * Owns the single shared category dropdown rendered once per page (#shared-category-panel-host).
 *
 * Row-level `inline-category` controllers reach this controller through a Stimulus outlet and
 * call open/toggle on it, so the dropdown markup is rendered once instead of duplicated into
 * every transaction row (which previously ballooned the page to several MB).
 *
 * The panel is moved to <body> while open (portal pattern) so it escapes overflow clipping from
 * the table's scroll containers, then parked back in this controller's element when closed.
 */
export default class extends Controller {
  connect() {
    this.panel = this.element.querySelector("[data-role='category-panel']")
    if (!this.panel) return

    this.search = this.panel.querySelector("[data-role='category-search']")
    this.activeRow = null
    this.boundClickOutside = this.onClickOutside.bind(this)
    this.boundKeydown = this.onKeydown.bind(this)

    this.panel.addEventListener("click", this.onPanelClick.bind(this))
    if (this.search) {
      this.search.addEventListener("input", () => this.filter())
    }
  }

  disconnect() {
    this.teardownDocumentListeners()
    // Re-park the panel so it isn't orphaned in <body> after a Turbo render.
    if (this.panel && this.panel.parentElement === document.body) {
      this.element.appendChild(this.panel)
    }
  }

  // --- called by inline-category row controllers via outlet ---

  toggle(rowController) {
    if (this.activeRow === rowController) {
      this.close()
    } else {
      this.open(rowController)
    }
  }

  open(rowController) {
    if (!this.panel) return

    this.activeRow = rowController
    document.body.appendChild(this.panel)
    this.position(rowController.triggerTarget)
    this.highlight(rowController.currentCategoryIdValue)
    this.panel.style.display = ""

    if (this.search) {
      this.search.value = ""
      this.filter()
      setTimeout(() => this.search.focus(), 50)
    }

    // Delay so the opening click doesn't immediately close the panel.
    setTimeout(() => {
      document.addEventListener("click", this.boundClickOutside)
      document.addEventListener("keydown", this.boundKeydown)
    }, 10)
  }

  close() {
    if (!this.panel) return
    this.panel.style.display = "none"
    this.element.appendChild(this.panel)
    this.activeRow = null
    this.teardownDocumentListeners()
  }

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
  }

  // --- private ---

  highlight(currentId) {
    if (!this.panel) return
    const id = currentId == null ? "" : String(currentId)
    this.panel.querySelectorAll("[data-category-id]").forEach(item => {
      const selected = (item.dataset.categoryId || "") === id
      item.classList.toggle("bg-blue-50", selected)
      item.classList.toggle("text-blue-700", selected)
    })
  }

  position(trigger) {
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
  }

  onPanelClick(event) {
    const btn = event.target.closest("[data-category-id]")
    if (!btn || !this.activeRow) return

    event.preventDefault()
    event.stopPropagation()

    const row = this.activeRow
    const categoryId = btn.dataset.categoryId
    this.close()
    row.selectCategory(categoryId)
  }

  onClickOutside(event) {
    const insidePanel = this.panel.contains(event.target)
    const insideRow = this.activeRow?.element.contains(event.target)
    if (!insidePanel && !insideRow) {
      this.close()
    }
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  teardownDocumentListeners() {
    document.removeEventListener("click", this.boundClickOutside)
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
