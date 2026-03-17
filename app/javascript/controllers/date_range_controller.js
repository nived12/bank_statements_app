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

    // Build default dates
    let defaultDate = null
    if (fromDate && toDate) {
      defaultDate = [this.convertUTCToLocal(fromDate), this.convertUTCToLocal(toDate)]
    } else if (fromDate) {
      defaultDate = this.convertUTCToLocal(fromDate)
    } else if (toDate) {
      defaultDate = this.convertUTCToLocal(toDate)
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
          const startLocal = selectedDates[0].toISOString().split("T")[0]
          const endLocal = selectedDates[1].toISOString().split("T")[0]

          this.fromDateTarget.value = window.convertLocalDateToUTC
            ? window.convertLocalDateToUTC(startLocal)
            : startLocal
          this.toDateTarget.value = window.convertLocalDateToUTC
            ? window.convertLocalDateToUTC(endLocal)
            : endLocal

          this.inputTarget.value = `${startLocal} - ${endLocal}`
          this.submitForm()
        } else if (selectedDates.length === 1) {
          const dateLocal = selectedDates[0].toISOString().split("T")[0]
          this.inputTarget.value = `${dateLocal} - `
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
      this.inputTarget.value = `${this.convertUTCToLocal(fromDate)} - ${this.convertUTCToLocal(toDate)}`
    } else if (fromDate) {
      this.inputTarget.value = `${this.convertUTCToLocal(fromDate)} -`
    } else if (toDate) {
      this.inputTarget.value = `- ${this.convertUTCToLocal(toDate)}`
    }
  }

  convertUTCToLocal(utcDateString) {
    if (!utcDateString) return utcDateString
    try {
      const utcDate = new Date(utcDateString + "T00:00:00.000Z")
      const localDate = new Date(utcDate.getTime() - (utcDate.getTimezoneOffset() * 60000))
      return localDate.toISOString().split("T")[0]
    } catch {
      return utcDateString
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
