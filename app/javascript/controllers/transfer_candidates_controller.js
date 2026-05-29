import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "badge", "modal", "tableBody", "resultEl"]
  static values = {
    noCandidatesText: String,
    sameDayText: String,
    oneDayApartText: String
  }

  connect() {
    this.checkOnLoad()
  }

  // Check for pending linkable candidates and show/hide the review button
  checkOnLoad() {
    fetch("/transactions/check_transfer_candidates", {
      headers: { "X-Requested-With": "XMLHttpRequest", "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        if (data.has_candidates) {
          this.showButton(data.candidates_count)
        } else {
          this.hideButton()
        }
      })
      .catch(() => this.hideButton())
  }

  // Open modal: fetch candidates and render table
  open() {
    fetch("/transactions/get_transfer_candidates", {
      headers: { "X-Requested-With": "XMLHttpRequest", "Accept": "application/json" }
    })
      .then(r => r.json())
      .then(data => {
        const candidates = data.candidates || []
        if (candidates.length > 0) {
          this.renderTable(candidates)
          this.modalTarget.classList.remove("hidden")
        } else {
          this.hideButton()
        }
      })
      .catch(() => {})
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  linkSelected() {
    const checked = this.tableBodyTarget.querySelectorAll("input[type='checkbox']:checked")
    const unchecked = this.tableBodyTarget.querySelectorAll("input[type='checkbox']:not(:checked)")
    const acceptedIds = Array.from(checked).map(cb => cb.value)
    const rejectedIds = Array.from(unchecked).map(cb => cb.value)
    if (acceptedIds.length === 0 && rejectedIds.length === 0) return
    this.submitCandidates(acceptedIds, rejectedIds)
  }

  dismissSelected() {
    const allIds = Array.from(
      this.tableBodyTarget.querySelectorAll("input[type='checkbox']")
    ).map(cb => cb.value)
    if (allIds.length === 0) return
    this.submitCandidates([], allIds)
  }

  // Trigger transfer reconciliation (called from the Reconcile Transfers button)
  reconcile(event) {
    const btn = event.currentTarget
    const { fromDate, toDate } = btn.dataset

    btn.disabled = true
    btn.classList.add("opacity-60", "cursor-not-allowed")

    if (this.hasResultElTarget) {
      this.resultElTarget.classList.add("hidden")
    }

    const params = new URLSearchParams()
    if (fromDate) params.append("from_date", fromDate)
    if (toDate) params.append("to_date", toDate)

    fetch(`/transactions/reconcile_transfers?${params}`, {
      method: "POST",
      headers: {
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").getAttribute("content")
      }
    })
      .then(r => r.json())
      .then(data => {
        btn.disabled = false
        btn.classList.remove("opacity-60", "cursor-not-allowed")

        if (data.success && this.hasResultElTarget) {
          const hasMatches = data.auto_linked > 0 || data.candidates_created > 0

          if (data.candidates_created > 0) {
            this.resultElTarget.innerHTML = `<button type="button" class="text-sm text-indigo-600 font-medium underline hover:text-indigo-800 transition-colors">${data.message}</button>`
            this.resultElTarget.querySelector("button").addEventListener("click", () => this.open())
            this.resultElTarget.className = ""
            this.resultElTarget.classList.remove("hidden")
            this.checkOnLoad()
          } else {
            this.resultElTarget.textContent = data.message
            this.resultElTarget.className = hasMatches
              ? "text-sm text-indigo-600 font-medium"
              : "text-sm text-slate-500"
            this.resultElTarget.classList.remove("hidden")
          }

          if (data.auto_linked > 0) setTimeout(() => window.location.reload(), 1500)
        }
      })
      .catch(() => {
        btn.disabled = false
        btn.classList.remove("opacity-60", "cursor-not-allowed")
      })
  }

  // Private

  submitCandidates(acceptedIds, rejectedIds) {
    fetch("/transactions/process_transfer_candidates", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").getAttribute("content")
      },
      body: JSON.stringify({ accepted_ids: acceptedIds, rejected_ids: rejectedIds })
    })
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          this.close()
          window.location.reload()
        }
      })
      .catch(() => {})
  }

  showButton(count) {
    if (this.hasButtonTarget) this.buttonTarget.classList.remove("hidden")
    if (this.hasBadgeTarget) {
      this.badgeTarget.classList.remove("hidden")
      this.badgeTarget.textContent = count
    }
  }

  hideButton() {
    if (this.hasButtonTarget) this.buttonTarget.classList.add("hidden")
    if (this.hasBadgeTarget) this.badgeTarget.classList.add("hidden")
  }

  renderTable(candidates) {
    if (candidates.length === 0) {
      this.tableBodyTarget.innerHTML = `
        <tr>
          <td colspan="6" class="border border-slate-300 px-4 py-8 text-center text-slate-500">
            ${this.noCandidatesTextValue}
          </td>
        </tr>
      `
      return
    }

    const rows = candidates.map(candidate => {
      const { outgoing, incoming } = candidate
      const daysDiff = Math.round(
        Math.abs(new Date(outgoing.date) - new Date(incoming.date)) / 86400000
      )
      const dateDiffLabel = daysDiff === 0 ? this.sameDayTextValue : this.oneDayApartTextValue
      const dateDiffClass = daysDiff === 0
        ? "bg-green-100 text-green-800"
        : "bg-amber-100 text-amber-800"

      return `
        <tr class="border-t border-slate-300 hover:bg-slate-50">
          <td class="border border-slate-300 px-4 py-3 text-center">
            <input type="checkbox"
                   value="${candidate.id}"
                   checked
                   class="transfer-candidate-checkbox rounded border-slate-300 text-indigo-600 focus:ring-indigo-500">
          </td>
          <td class="border border-slate-300 px-4 py-3 text-sm">
            <div class="font-medium text-slate-900">${this.esc(outgoing.bank_account.display_name)}</div>
            <div class="text-xs text-slate-500 mt-0.5">${this.formatDate(outgoing.date)}</div>
            <div class="text-xs text-slate-600 mt-0.5 truncate max-w-[200px]" title="${this.esc(outgoing.description)}">${this.esc(outgoing.concept || outgoing.description)}</div>
          </td>
          <td class="border border-slate-300 px-2 py-3 text-center">
            <svg class="w-5 h-5 text-indigo-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"></path>
            </svg>
          </td>
          <td class="border border-slate-300 px-4 py-3 text-sm">
            <div class="font-medium text-slate-900">${this.esc(incoming.bank_account.display_name)}</div>
            <div class="text-xs text-slate-500 mt-0.5">${this.formatDate(incoming.date)}</div>
            <div class="text-xs text-slate-600 mt-0.5 truncate max-w-[200px]" title="${this.esc(incoming.description)}">${this.esc(incoming.concept || incoming.description)}</div>
          </td>
          <td class="border border-slate-300 px-4 py-3 text-right text-sm font-medium text-slate-900">
            ${formatMoney(outgoing.amount)}
          </td>
          <td class="border border-slate-300 px-4 py-3 text-center">
            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${dateDiffClass}">
              ${dateDiffLabel}
            </span>
          </td>
        </tr>
      `
    })

    this.tableBodyTarget.innerHTML = rows.join("")
  }

  formatDate(dateString) {
    if (!dateString) return ""
    try {
      return new Date(dateString + "T00:00:00").toLocaleDateString("es-MX", {
        year: "numeric", month: "long", day: "numeric"
      })
    } catch {
      return dateString
    }
  }

  esc(str) {
    return (str || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }
}
