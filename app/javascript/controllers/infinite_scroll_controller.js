import { Controller } from "@hotwired/stimulus"
import { resolveLocale } from "./utils/locale"

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

    // Mobile date groups — merge by date so a day spanning a page boundary
    // doesn't render a duplicate header (mirrors the native app's regrouping).
    const tempDiv = document.createElement("div")
    tempDiv.innerHTML = html
    const incoming = tempDiv.querySelector("[data-mobile-transactions-list]")
    const mobileList = frame.querySelector("[data-mobile-transactions-list]")
    if (mobileList && incoming) {
      incoming.querySelectorAll(".mobile-tx-group").forEach(group => {
        const date = group.dataset.date
        const existing = date && mobileList.querySelector(`.mobile-tx-group[data-date="${date}"]`)
        if (existing) {
          const targetCard = existing.querySelector(".mobile-tx-card")
          const incomingCard = group.querySelector(".mobile-tx-card")
          if (targetCard && incomingCard) {
            incomingCard.querySelectorAll(".mobile-tx-row").forEach(row => targetCard.appendChild(row))
          }
          const newTotal = Math.round((parseFloat(existing.dataset.dayTotal || "0") + parseFloat(group.dataset.dayTotal || "0")) * 100) / 100
          existing.dataset.dayTotal = String(newTotal)
          this.updateDayTotal(existing, newTotal)
        } else {
          mobileList.appendChild(group)
        }
      })
    }
  }

  // Re-render a merged day's total header to match format_money(:always_sign).
  updateDayTotal(group, total) {
    const span = group.querySelector(".mobile-date-section-header span:last-child")
    if (!span) return
    const formatted = new Intl.NumberFormat(resolveLocale(), {
      style: "currency",
      currency: "MXN",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(Math.abs(total))
    span.textContent = `${total >= 0 ? "+" : "-"}${formatted}`
    span.classList.toggle("money-positive", total >= 0)
    span.classList.toggle("money-negative", total < 0)
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
