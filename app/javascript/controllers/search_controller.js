import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["input", "form", "clearButton"]
  static values = {
    debounceDelay: { type: Number, default: 300 },
    submitUrl: String
  }

  connect() {
    this.timeout = null
    this.showClearButton()
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Handle input changes with debouncing
  search(event) {
    // Clear any existing timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Handle Enter key - submit immediately
    if (event.key === 'Enter') {
      event.preventDefault()
      this.submitSearch()
      return
    }

    // Show/hide clear button based on input value
    this.showClearButton()

    // If input is empty, submit immediately (no delay for clearing)
    const currentValue = this.inputTarget.value.trim()
    if (currentValue === '') {
      this.submitSearch()
      return
    }

    // Debounce the search for non-empty values
    this.timeout = setTimeout(() => {
      this.submitSearch()
    }, this.debounceDelayValue)
  }

  // Clear the search input and submit
  clear() {
    this.inputTarget.value = ''
    this.inputTarget.focus()
    this.showClearButton()
    this.submitSearch()
  }

  // Submit the search form
  submitSearch() {
    if (this.hasFormTarget) {
      // If we have a form target, submit it (Turbo will handle the response)
      this.formTarget.requestSubmit()
    } else {
      // Fallback: construct URL and navigate with Turbo
      this.submitWithTurbo()
    }
  }

  // Fallback method for URL-based submission
  submitWithTurbo() {
    const url = new URL(window.location)
    const searchValue = this.inputTarget.value.trim()

    if (searchValue) {
      url.searchParams.set('search', searchValue)
    } else {
      url.searchParams.delete('search')
    }

    // Use Turbo for navigation (Hotwire Native compatible)
    Turbo.visit(url.toString(), { frame: "_top" })
  }

  // Show/hide clear button based on input value
  showClearButton() {
    if (this.hasClearButtonTarget) {
      const hasValue = this.inputTarget.value.trim().length > 0
      this.clearButtonTarget.classList.toggle('hidden', !hasValue)
    }
  }

  // Focus the input (useful for programmatic focus)
  focus() {
    this.inputTarget.focus()
  }
}