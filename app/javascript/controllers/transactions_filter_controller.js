import { Controller } from "@hotwired/stimulus"

// Unified filter/sort controller for the transactions index page.
// Owns the desktop filter form; syncs hidden sort inputs after turbo-frame
// sort updates so that subsequent filter submissions preserve the sort.
export default class extends Controller {
  static targets = [
    "form",
    "sortInput",
    "directionInput",
    "bankAccountSelect",
    "statementFileSelect",
    "transactionTypeSelect",
    "fromDate",
    "toDate",
    "searchInput",
    "categorySearch",
    "categoryList"
  ]

  connect() {
    this.boundSyncSort = this.syncSort.bind(this)
    document.addEventListener("turbo:frame-load", this.boundSyncSort)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundSyncSort)
  }

  // Called on turbo:frame-load — reads data attributes from the turbo frame
  // and writes them into the hidden sort/direction inputs so they survive
  // the next form submission.
  syncSort(event) {
    if (event.target.id !== "transactions-stats-and-results") return

    const frame = event.target
    const sort = frame.dataset.currentSort || ""
    const direction = frame.dataset.currentDirection || ""

    if (this.hasSortInputTarget) {
      this.sortInputTarget.value = sort
    }
    if (this.hasDirectionInputTarget) {
      this.directionInputTarget.value = direction
    }
  }

  // Generic filter change — just submit the form (targets turbo frame).
  applyFilter() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  // Parent category checkbox — cascade check/uncheck to all children, then filter.
  parentCategoryChanged(event) {
    const checkbox = event.currentTarget
    const childIds = (checkbox.dataset.childIds || "").split(",").filter(Boolean)

    childIds.forEach(id => {
      const child = this.formTarget.querySelector(`input[name="category_ids[]"][value="${id}"]`)
      if (child) child.checked = checkbox.checked
    })

    this.applyFilter()
  }

  // Bank account change — cascade statement files, then submit.
  bankAccountChanged() {
    const bankAccountId = this.bankAccountSelectTarget.value

    // Clear statement file selection
    if (this.hasStatementFileSelectTarget) {
      this.statementFileSelectTarget.value = ""
      this.updateStatementFiles(bankAccountId)
    }

    this.applyFilter()
  }

  // Fetch statement files for the selected bank account and repopulate the dropdown.
  updateStatementFiles(bankAccountId) {
    const select = this.statementFileSelectTarget
    const url = bankAccountId
      ? `/transactions/statement_files?bank_account_id=${bankAccountId}`
      : "/transactions/statement_files"

    // Keep only the first "all" option
    const allOption = select.querySelector("option:first-child")
    select.innerHTML = ""
    if (allOption) select.appendChild(allOption)

    fetch(url, {
      headers: {
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json"
      }
    })
      .then(response => response.json())
      .then(data => {
        data.statement_files.forEach(file => {
          const option = document.createElement("option")
          option.value = file.id
          option.textContent = `${file.safe_filename} - ${file.bank_account_display_name}`
          select.appendChild(option)
        })
      })
      .catch(() => {
        // Silently fail — the dropdown just won't update
      })
  }

  // Clear a single filter by name.
  clearFilter(event) {
    const filterName = event.params.name
    const el = this.formTarget.querySelector(`[name="${filterName}"]`)
    if (el) {
      el.value = ""
    }
    this.applyFilter()
  }

  // Clear date filters (from_date, to_date, and the visible date_range input).
  clearDateFilter() {
    if (this.hasFromDateTarget) this.fromDateTarget.value = ""
    if (this.hasToDateTarget) this.toDateTarget.value = ""

    const dateRange = this.formTarget.querySelector("#date_range")
    if (dateRange) {
      dateRange.value = ""
      // Clear flatpickr instance if present
      if (dateRange._flatpickr) dateRange._flatpickr.clear()
    }

    this.applyFilter()
  }

  // Clear search input.
  clearSearch() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }
    this.applyFilter()
  }

  // Clear all filters and navigate to clean URL.
  clearAllFilters() {
    window.location.href = "/transactions"
  }

  // Debounced search — called from input event.
  search() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.applyFilter()
    }, 300)
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

  // Immediate search submit on Enter.
  searchKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      clearTimeout(this.searchTimeout)
      this.applyFilter()
    }
  }
}
