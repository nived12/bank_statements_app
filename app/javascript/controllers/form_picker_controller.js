import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel", "input", "label", "option", "search", "group"]
  static values = { selected: String }

  connect() {
    this.escapeHandler = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }

  open() {
    this.overlayTarget.classList.add("open")
    requestAnimationFrame(() => {
      this.panelTarget.classList.add("open")
    })
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.escapeHandler)
    // Reset search on open
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this._applyFilter("")
      requestAnimationFrame(() => this.searchTarget.focus())
    }
  }

  close() {
    this.panelTarget.classList.remove("open")
    this.overlayTarget.classList.remove("open")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.escapeHandler)
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  filter(event) {
    this._applyFilter(event.target.value)
  }

  _applyFilter(query) {
    const q = query.toLowerCase().trim()
    this.optionTargets.forEach((option) => {
      const label = (option.dataset.label || option.textContent || "").toLowerCase()
      option.hidden = q.length > 0 && !label.includes(q)
    })
    // Hide group headers when all their options are hidden
    if (this.hasGroupTarget) {
      this.groupTargets.forEach((group) => {
        const anyVisible = [...group.querySelectorAll("[data-form-picker-target='option']")]
          .some((opt) => !opt.hidden)
        group.hidden = !anyVisible
      })
    }
  }

  select(event) {
    const option = event.currentTarget
    const value = option.dataset.value
    const label = option.dataset.label

    if (this.hasInputTarget) {
      this.inputTarget.value = value
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = label
      this.labelTarget.classList.toggle("tx-field-row-placeholder", !value)
      this.labelTarget.classList.toggle("tx-field-row-text", !!value)
    }

    this.optionTargets.forEach((el) => {
      el.classList.toggle("selected", el === option)
    })

    this.selectedValue = value
    this.dispatch("selected", { detail: { value, label } })
    this.close()
  }
}
