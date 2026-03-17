import { Controller } from "@hotwired/stimulus"

/**
 * Multi-select controller for expandable selection UI.
 * Supports both multi-select (checkboxes) and single-select (radio buttons).
 */
export default class extends Controller {
  static targets = ["container", "button", "selectAllButton", "checkbox", "summary", "radioButton", "categoryLabel", "searchInput"]

  connect() {
    // Only update summary for multi-select (checkbox) mode, not single-select (radio) mode
    if (this.hasCheckboxTarget) {
      this.updateSummary()
    }
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.containerTarget.classList.contains("hidden")

    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.containerTarget.classList.remove("hidden")
    this.buttonTarget.querySelector("svg").classList.add("rotate-180")
    // Clear search and show all categories when opening
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
      this.filterCategories()
      this.searchInputTarget.focus()
    }
    // Add click outside listener after a short delay to prevent immediate close
    setTimeout(() => {
      document.addEventListener("click", this.boundHandleClickOutside)
    }, 100)
  }

  close() {
    this.containerTarget.classList.add("hidden")
    this.buttonTarget.querySelector("svg").classList.remove("rotate-180")
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  handleClickOutside(event) {
    // Check if click is outside the entire multi-select component
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  toggleAll(event) {
    event.stopPropagation()
    const checkboxes = this.checkboxTargets
    const allChecked = checkboxes.every(cb => cb.checked)

    checkboxes.forEach(cb => {
      cb.checked = !allChecked
    })

    this.updateSummary()
    this.updateSelectAllButton()
  }

  updateCount() {
    this.updateSummary()
    this.updateSelectAllButton()
  }

  updateSummary() {
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked).length
    const totalCount = this.checkboxTargets.length

    if (checkedCount === 0) {
      this.summaryTarget.textContent = this.summaryTarget.dataset.placeholder
      this.summaryTarget.classList.add("text-slate-400")
      this.summaryTarget.classList.remove("text-slate-900")
    } else {
      this.summaryTarget.textContent = `${checkedCount} selected`
      this.summaryTarget.classList.remove("text-slate-400")
      this.summaryTarget.classList.add("text-slate-900")
    }
  }

  updateSelectAllButton() {
    const checkboxes = this.checkboxTargets
    const allChecked = checkboxes.every(cb => cb.checked)

    if (allChecked) {
      this.selectAllButtonTarget.textContent = this.selectAllButtonTarget.dataset.unselectText || "Unselect all"
    } else {
      this.selectAllButtonTarget.textContent = this.selectAllButtonTarget.dataset.selectText || "Select all"
    }
  }

  /**
   * Handles radio button selection for single-select mode (e.g., category picker).
   * Updates the selected label styling and summary text.
   * @param {Event} event - The change event from the radio button
   */
  selectCategory(event) {
    const radioButton = event.target
    const categoryName = radioButton.dataset.categoryName

    // Remove highlight from all category labels
    if (this.hasCategoryLabelTarget) {
      this.categoryLabelTargets.forEach(label => {
        label.classList.remove('bg-blue-50', 'border', 'border-blue-200')
        label.classList.add('hover:bg-slate-50')
      })
    }

    // Add highlight to selected label
    const selectedLabel = radioButton.closest('[data-multi-select-target="categoryLabel"]')
    if (selectedLabel) {
      selectedLabel.classList.add('bg-blue-50', 'border', 'border-blue-200')
      selectedLabel.classList.remove('hover:bg-slate-50')
    }

    // Update summary text
    if (this.hasSummaryTarget && categoryName) {
      this.summaryTarget.textContent = categoryName
      this.summaryTarget.classList.remove('text-slate-400')
      this.summaryTarget.classList.add('text-slate-900')
    }

    // Close the dropdown after selection
    this.close()
  }

  /**
   * Filters category labels by matching search text against category names (case-insensitive).
   */
  filterCategories() {
    if (!this.hasSearchInputTarget || !this.hasCategoryLabelTarget) return

    const query = this.searchInputTarget.value.toLowerCase().trim()
    const labels = this.categoryLabelTargets

    if (!query) {
      labels.forEach(label => label.style.display = "")
      return
    }

    // First pass: find direct matches
    const matchedIds = new Set()
    const matchedParentIds = new Set()

    labels.forEach(label => {
      const name = label.querySelector("span:last-of-type")?.textContent?.toLowerCase() || ""
      if (name.includes(query)) {
        const id = label.dataset.categoryId
        const parentId = label.dataset.categoryParentId
        matchedIds.add(id)
        if (parentId) matchedParentIds.add(parentId)
      }
    })

    // Second pass: show matched items, their parents, and children of matched parents
    labels.forEach(label => {
      const id = label.dataset.categoryId
      const parentId = label.dataset.categoryParentId
      const isMatch = matchedIds.has(id)
      const isParentOfMatch = matchedParentIds.has(id)
      const isChildOfMatch = parentId && matchedIds.has(parentId)

      label.style.display = (isMatch || isParentOfMatch || isChildOfMatch) ? "" : "none"
    })
  }

  /**
   * Clears the category selection for single-select mode.
   * Removes all styling and resets the summary text.
   * @param {Event} event - The click event from the clear button
   */
  clearCategory(event) {
    event.preventDefault()
    event.stopPropagation()

    // Uncheck all radio buttons
    if (this.hasRadioButtonTarget) {
      this.radioButtonTargets.forEach(radio => {
        radio.checked = false
      })
    }

    // Remove highlight from all labels
    if (this.hasCategoryLabelTarget) {
      this.categoryLabelTargets.forEach(label => {
        label.classList.remove('bg-blue-50', 'border', 'border-blue-200')
        label.classList.add('hover:bg-slate-50')
      })
    }

    // Reset summary text
    if (this.hasSummaryTarget) {
      const placeholder = this.summaryTarget.dataset.placeholder
      this.summaryTarget.textContent = placeholder
      this.summaryTarget.classList.add('text-slate-400')
      this.summaryTarget.classList.remove('text-slate-900')
    }
  }
}
