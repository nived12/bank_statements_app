import { Controller } from "@hotwired/stimulus"

// Infinite scroll controller for the transactions index.
// Reads pagination state and filter params from data attributes on the
// container element rather than window.location, so it works correctly
// after turbo-frame filter/sort updates.
export default class extends Controller {
  static values = {
    nextPage: Number,
    totalPages: Number,
    totalCount: Number
  }

  connect() {
    this.isLoading = false
    this.observer = null
    this.setupObserver()

    // Re-setup after turbo frame reloads (filter/sort changes)
    this.boundReconnect = this.reconnect.bind(this)
    document.addEventListener("turbo:frame-load", this.boundReconnect)
  }

  disconnect() {
    this.teardownObserver()
    document.removeEventListener("turbo:frame-load", this.boundReconnect)
  }

  reconnect(event) {
    if (event.target.id !== "transactions-stats-and-results") return
    // Only react if this controller's element is inside the updated frame
    if (!event.target.contains(this.element)) return

    // Wait a tick for the DOM to settle after frame replacement
    requestAnimationFrame(() => {
      this.isLoading = false
      this.teardownObserver()
      this.setupObserver()
    })
  }

  setupObserver() {
    if (!this.hasNextPageValue || this.nextPageValue <= 0) return
    if (this.nextPageValue > this.totalPagesValue) return

    const trigger = this.element.querySelector(".scroll-trigger")
    if (!trigger) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.isLoading) {
          this.loadMore()
        }
      })
    }, { rootMargin: "100px" })

    this.observer.observe(trigger)
  }

  teardownObserver() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  }

  loadMore() {
    if (this.isLoading) return

    const nextPage = this.nextPageValue
    const totalPages = this.totalPagesValue

    if (!nextPage || nextPage > totalPages) {
      this.hideScrollTrigger()
      return
    }

    this.isLoading = true
    this.showIndicator()

    // Build URL from data-filter-params (NOT window.location)
    const filterParamsAttr = this.element.dataset.filterParams
    let params = {}
    if (filterParamsAttr) {
      try {
        params = JSON.parse(filterParamsAttr)
      } catch (e) {
        // Fall back to empty params
      }
    }

    const url = new URL("/transactions", window.location.origin)
    url.searchParams.set("page", nextPage)
    Object.entries(params).forEach(([key, value]) => {
      if (value !== null && value !== undefined && value !== "") {
        url.searchParams.set(key, value)
      }
    })

    fetch(url, {
      headers: {
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "text/html"
      }
    })
      .then(response => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.text()
      })
      .then(html => {
        this.appendRows(html)
        this.updateState(nextPage, totalPages)
      })
      .catch(error => {
        console.error("Error loading more transactions:", error)
      })
      .finally(() => {
        this.hideIndicator()
        this.isLoading = false
      })
  }

  appendRows(html) {
    // Scope queries to the parent turbo frame
    const frame = this.element.closest("turbo-frame") || document

    // Desktop table rows
    const tempTable = document.createElement("table")
    tempTable.innerHTML = html
    const tableRows = tempTable.querySelectorAll("tr.transactions-table-row")
    const tbody = frame.querySelector("[data-transactions-tbody]")
    if (tbody && tableRows.length > 0) {
      tableRows.forEach(row => tbody.appendChild(row))
    }

    // Mobile date groups
    const tempDiv = document.createElement("div")
    tempDiv.innerHTML = html
    const mobileGroups = tempDiv.querySelector("[data-mobile-transactions-list]")
    const mobileList = frame.querySelector("[data-mobile-transactions-list]")
    if (mobileList && mobileGroups) {
      mobileGroups.querySelectorAll(".mobile-date-group").forEach(group => {
        mobileList.appendChild(group)
      })
    }
  }

  updateState(currentPage, totalPages) {
    if (currentPage >= totalPages) {
      this.hideScrollTrigger()
      this.teardownObserver()
    } else {
      this.nextPageValue = currentPage + 1
    }

    // Update loaded count display
    const frame = this.element.closest("turbo-frame") || document
    const tbody = frame.querySelector("[data-transactions-tbody]")
    const loadedCount = tbody ? tbody.querySelectorAll("tr").length : 0
    const countSpan = this.element.querySelector(".transactions-loaded-count")
    if (countSpan) {
      countSpan.textContent = loadedCount
    }
  }

  hideScrollTrigger() {
    const trigger = this.element.querySelector(".scroll-trigger")
    if (trigger) trigger.style.display = "none"
  }

  showIndicator() {
    const indicator = this.element.querySelector(".infinite-scroll-indicator")
    if (indicator) indicator.classList.remove("hidden")
  }

  hideIndicator() {
    const indicator = this.element.querySelector(".infinite-scroll-indicator")
    if (indicator) indicator.classList.add("hidden")
  }
}
