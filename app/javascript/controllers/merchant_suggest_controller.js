import { Controller } from "@hotwired/stimulus"

/**
 * Merchant auto-suggest controller.
 *
 * On merchant field blur → GET /category_rules/lookup?merchant=X
 * If a matching rule exists and no category is selected yet, pre-select it.
 *
 * On category radio change (manual user pick) → POST /category_rules/upsert
 * Silently saves merchant → category rule for future auto-suggest.
 */
export default class extends Controller {
  static targets = ["merchant", "categoryField"]
  static values = {
    lookupUrl: { type: String, default: "/category_rules/lookup" },
    upsertUrl: { type: String, default: "/category_rules/upsert" }
  }

  connect() {
    this._autoSuggested = false
    this._boundOnCategoryChange = this._onCategoryChange.bind(this)
    this.element.addEventListener("change", this._boundOnCategoryChange)
  }

  disconnect() {
    this.element.removeEventListener("change", this._boundOnCategoryChange)
  }

  async lookup() {
    const merchant = this._merchantValue()
    if (!merchant) return

    // Don't overwrite an existing selection
    const existing = this.element.querySelector("input[name='transaction[category_id]']:checked")
    if (existing && existing.value) return

    try {
      const url = `${this.lookupUrlValue}?merchant=${encodeURIComponent(merchant)}`
      const res  = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) return

      const { category_id } = await res.json()
      if (!category_id) return

      // Find the matching radio button and trigger it programmatically
      const radio = this.element.querySelector(
        `input[name='transaction[category_id]'][value='${category_id}']`
      )
      if (!radio) return

      this._autoSuggested = true
      radio.checked = true
      radio.dispatchEvent(new Event("change", { bubbles: true }))
      this._autoSuggested = false
    } catch {
      // Lookup errors are silent — don't disrupt the user
    }
  }

  // --- private ---

  _merchantValue() {
    if (this.hasMerchantTarget) return this.merchantTarget.value.trim()
    // Fallback: find merchant input by name within the form
    const input = this.element.querySelector("input[name='transaction[merchant]']")
    return input ? input.value.trim() : ""
  }

  async _onCategoryChange(event) {
    if (event.target.name !== "transaction[category_id]") return
    if (this._autoSuggested) return

    const categoryId = event.target.value
    const merchant   = this._merchantValue()
    if (!merchant || !categoryId) return

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      await fetch(this.upsertUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":  csrfToken,
          Accept:          "application/json"
        },
        body: JSON.stringify({ merchant, category_id: categoryId })
      })
    } catch {
      // Upsert errors are silent — rule saving is best-effort
    }
  }
}
