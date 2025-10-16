import { Controller } from "@hotwired/stimulus"

// Category Selector - Modern hierarchical category dropdown
export default class extends Controller {
  static targets = ["menu", "selectedValue", "selectedText", "hiddenInput"]
  static values = {
    selected: String
  }

  connect() {
    this.expandedParents = new Set()

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

  toggle(event) {
    event?.preventDefault()
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    // Add click outside listener after a brief delay
    setTimeout(() => {
      document.addEventListener("click", this.clickOutsideHandler)
    }, 10)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.clickOutsideHandler)
  }

  selectCategory(event) {
    event.preventDefault()
    const item = event.currentTarget
    const categoryId = item.dataset.categoryId
    const categoryName = item.dataset.categoryName
    const hasChildren = item.dataset.hasChildren === "true"
    const isParent = item.dataset.isParent === "true"

    // If it's a parent category with children
    if (isParent && hasChildren) {
      const parentId = categoryId

      // If this parent is already expanded
      if (this.expandedParents.has(parentId)) {
        // Second click on expanded parent = select it
        this.setSelection(categoryId, categoryName)
        this.close()
      } else {
        // First click = expand to show children
        this.toggleParent(parentId)
      }
    } else {
      // It's a child category or parent without children = select immediately
      this.setSelection(categoryId, categoryName)
      this.close()
    }
  }

  toggleParent(parentId) {
    const submenu = this.element.querySelector(`[data-parent-submenu="${parentId}"]`)
    const arrow = this.element.querySelector(`[data-parent-arrow="${parentId}"]`)

    if (!submenu) return

    if (this.expandedParents.has(parentId)) {
      // Collapse
      this.expandedParents.delete(parentId)
      submenu.classList.add("hidden")
      arrow?.classList.remove("rotate-90")
    } else {
      // Expand
      this.expandedParents.add(parentId)
      submenu.classList.remove("hidden")
      arrow?.classList.add("rotate-90")
    }
  }

  setSelection(categoryId, categoryName) {
    // Update hidden input
    this.hiddenInputTarget.value = categoryId

    // Update display
    this.selectedTextTarget.textContent = categoryName
    this.selectedValue = categoryId
  }

  clearSelection(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.hiddenInputTarget.value = ""
    this.selectedTextTarget.textContent = this.selectedTextTarget.dataset.placeholder || "Elige una categoría"
    this.selectedValue = ""
  }
}
