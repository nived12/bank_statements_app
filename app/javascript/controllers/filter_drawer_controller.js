import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-drawer"
export default class extends Controller {
  static targets = ["drawer", "overlay", "badge", "form", "categorySearch", "categoryList"]
  static values = {
    isOpen: { type: Boolean, default: false }
  }

  connect() {
    // Ensure drawer starts closed
    this.isOpenValue = false
    this.ensureClosedState()
    this.updateBadge()
    // Close drawer when clicking outside
    this.boundCloseOnOutside = this.closeOnOutside.bind(this)
  }

  // Ensure the drawer is in the proper closed state
  ensureClosedState() {
    if (this.hasDrawerTarget && this.hasOverlayTarget) {
      this.drawerTarget.classList.add('translate-y-full')
      this.drawerTarget.classList.remove('translate-y-0')
      this.overlayTarget.classList.add('opacity-0', 'pointer-events-none')
      this.overlayTarget.classList.remove('opacity-50')
      document.body.style.overflow = ''
    }
  }

  disconnect() {
    document.removeEventListener('click', this.boundCloseOnOutside)
  }

  // Toggle the filter drawer open/closed
  toggle() {
    if (this.isOpenValue) {
      this.close()
    } else {
      this.open()
    }
  }

  // Open the filter drawer
  open() {
    this.isOpenValue = true
    this.drawerTarget.classList.remove('translate-y-full')
    this.drawerTarget.classList.add('translate-y-0')
    this.overlayTarget.classList.remove('opacity-0', 'pointer-events-none')
    this.overlayTarget.classList.add('opacity-50')

    // Prevent body scroll when drawer is open
    document.body.style.overflow = 'hidden'

    // Listen for outside clicks after a brief delay
    setTimeout(() => {
      document.addEventListener('click', this.boundCloseOnOutside)
    }, 100)
  }

  // Close the filter drawer
  close() {
    this.isOpenValue = false
    this.drawerTarget.classList.remove('translate-y-0')
    this.drawerTarget.classList.add('translate-y-full')
    this.overlayTarget.classList.remove('opacity-50')
    this.overlayTarget.classList.add('opacity-0', 'pointer-events-none')

    // Restore body scroll
    document.body.style.overflow = ''

    // Remove outside click listener
    document.removeEventListener('click', this.boundCloseOnOutside)
  }

  // Close drawer when clicking outside
  closeOnOutside(event) {
    // Check if click is inside a Flatpickr calendar
    const flatpickrCalendar = event.target.closest('.flatpickr-calendar')

    // Don't close if clicking inside drawer or inside Flatpickr calendar
    if (!this.drawerTarget.contains(event.target) && !flatpickrCalendar && this.isOpenValue) {
      this.close()
    }
  }

  // Handle filter chip clicks
  selectChip(event) {
    const label = event.currentTarget
    const input = label.querySelector('input[type="radio"]')

    if (input && !input.checked) {
      input.checked = true
      // Trigger change event to apply filter
      input.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  // Handle filter changes
  applyFilter(event) {
    // Update active state for chips
    if (event.target.type === 'radio') {
      const chipGroup = event.target.closest('.mobile-filter-chips')
      if (chipGroup) {
        // Remove active class from all chips in this group
        chipGroup.querySelectorAll('.mobile-filter-chip').forEach(chip => {
          chip.classList.remove('active')
        })
        // Add active class to the selected chip
        const selectedChip = event.target.closest('.mobile-filter-chip')
        if (selectedChip) {
          selectedChip.classList.add('active')
        }
      }
    }

    // Reset pagination to page 1 when filters change
    // Remove page parameter from URL to ensure we start from beginning
    const currentUrl = new URL(window.location)
    currentUrl.searchParams.delete('page')

    // Update URL without reloading to ensure clean state
    window.history.replaceState({}, '', currentUrl)

    // Get the form and submit it
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }

    // Update the badge count
    this.updateBadge()

    // Close drawer after applying filter (optional - you might want to keep it open)
    // this.close()
  }

  // Client-side filter for the category checkbox list — no form submit.
  filterCategories() {
    if (!this.hasCategorySearchTarget || !this.hasCategoryListTarget) return

    const query = this.categorySearchTarget.value.toLowerCase().trim()
    const labels = this.categoryListTarget.querySelectorAll("label[data-category-name]")

    if (!query) {
      labels.forEach(label => (label.style.display = ""))
      return
    }

    const matchedParentNames = new Set()
    labels.forEach(label => {
      const name = (label.dataset.categoryName || "").toLowerCase()
      if (name.includes(query) && label.dataset.categoryParentName) {
        matchedParentNames.add(label.dataset.categoryParentName.toLowerCase())
      }
    })

    labels.forEach(label => {
      const name = (label.dataset.categoryName || "").toLowerCase()
      const isMatch = name.includes(query)
      const isParentOfMatch = matchedParentNames.has(name)
      label.style.display = (isMatch || isParentOfMatch) ? "" : "none"
    })
  }

  // Parent category checkbox — cascade check/uncheck to all children, then filter.
  parentCategoryChanged(event) {
    const checkbox = event.currentTarget
    const childIds = (checkbox.dataset.childIds || "").split(",").filter(Boolean)

    childIds.forEach(id => {
      const child = this.element.querySelector(`input[name="category_ids[]"][value="${id}"]`)
      if (child) child.checked = checkbox.checked
    })

    this.applyFilter(event)
  }

  // Clear all filters
  clearAll() {
    // Clear all filter inputs
    const filterInputs = this.formTarget.querySelectorAll('select, input[type="text"], input[type="hidden"]')
    filterInputs.forEach(input => {
      if (input.type === 'select-one') {
        input.selectedIndex = 0
      } else {
        input.value = ''
      }
    })

    // Submit the form to apply cleared filters
    this.formTarget.requestSubmit()

    // Update badge
    this.updateBadge()

    // Close drawer
    this.close()
  }

  // Update the filter count badge
  updateBadge() {
    if (!this.hasBadgeTarget || !this.hasFormTarget) return

    const activeFilters = this.countActiveFilters()

    if (activeFilters > 0) {
      this.badgeTarget.textContent = activeFilters
      this.badgeTarget.classList.remove('hidden')
    } else {
      this.badgeTarget.classList.add('hidden')
    }
  }

  // Count active filters (excluding search, which is handled separately)
  countActiveFilters() {
    if (!this.hasFormTarget) return 0

    let count = 0
    const formData = new FormData(this.formTarget)

    // Check each filter field (excluding search which is separate)
    const filterFields = ['bank_account_id', 'statement_file_id', 'transaction_type', 'from_date', 'to_date']

    filterFields.forEach(field => {
      const value = formData.get(field)
      if (value && value.trim() !== '') {
        count++
      }
    })

    return count
  }

  // Handle swipe to close (for mobile)
  handleSwipe(event) {
    if (event.detail.direction === 'down' && this.isOpenValue) {
      this.close()
    }
  }
}
