import { Controller } from "@hotwired/stimulus"

// Flatpickr date range picker controller.
// Manages date range selection and syncs hidden from/to inputs.
// Dispatches form submission when a complete range is selected or cleared.
export default class extends Controller {
  static targets = ["input", "fromDate", "toDate"]
  static values = {
    fromDate: String,
    toDate: String
  }

  connect() {
    this.flatpickrRetries = 0
    this.waitForFlatpickr()
  }

  disconnect() {
    if (this.picker) {
      this.picker.destroy()
      this.picker = null
    }
  }

  waitForFlatpickr() {
    if (typeof window.flatpickr === "undefined") {
      this.flatpickrRetries += 1
      if (this.flatpickrRetries > 50) {
        console.warn("date-range: flatpickr not available after 5s, giving up")
        return
      }
      setTimeout(() => this.waitForFlatpickr(), 100)
      return
    }
    this.initializePicker()
  }

  initializePicker() {
    const fromDate = this.fromDateValue || this.fromDateTarget.value
    const toDate = this.toDateValue || this.toDateTarget.value

    // Set initial display value
    this.setDisplayValue(fromDate, toDate)

    // Build default dates — date strings are already in YYYY-MM-DD format
    let defaultDate = null
    if (fromDate && toDate) {
      defaultDate = [fromDate, toDate]
    } else if (fromDate) {
      defaultDate = fromDate
    } else if (toDate) {
      defaultDate = toDate
    }

    this.picker = window.flatpickr(this.inputTarget, {
      mode: "range",
      dateFormat: "Y-m-d",
      maxDate: "today",
      allowInput: false,
      clickOpens: true,
      defaultDate: defaultDate,
      onChange: (selectedDates) => {
        if (selectedDates.length === 2) {
          const startDate = selectedDates[0].toISOString().split("T")[0]
          const endDate = selectedDates[1].toISOString().split("T")[0]

          this.fromDateTarget.value = startDate
          this.toDateTarget.value = endDate
          this.inputTarget.value = `${startDate} - ${endDate}`
          this.submitForm()
        } else if (selectedDates.length === 1) {
          const date = selectedDates[0].toISOString().split("T")[0]
          this.inputTarget.value = `${date} - `
          // Wait for second date
        }
      },
      onClear: () => {
        this.fromDateTarget.value = ""
        this.toDateTarget.value = ""
        this.inputTarget.value = ""
        this.submitForm()
      }
    })
  }

  setDisplayValue(fromDate, toDate) {
    if (fromDate && toDate) {
      this.inputTarget.value = `${fromDate} - ${toDate}`
    } else if (fromDate) {
      this.inputTarget.value = `${fromDate} -`
    } else if (toDate) {
      this.inputTarget.value = `- ${toDate}`
    }
  }

  submitForm() {
    // Find the closest form and submit it
    const form = this.element.closest("form")
    if (form) {
      form.requestSubmit()
    }
  }

  // Action to clear the date range externally
  clear() {
    if (this.picker) {
      this.picker.clear()
    } else {
      this.fromDateTarget.value = ""
      this.toDateTarget.value = ""
      this.inputTarget.value = ""
      this.submitForm()
    }
  }
}
