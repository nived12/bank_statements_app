import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "patternDisplay", "patternInput",
    "matchDisplay", "matchSelect",
    "categoryDisplay", "categorySelect",
    "saveBtn", "cancelBtn"
  ]
  static values = {
    url: String,
    originalPattern: String,
    originalMatchType: String,
    originalCategoryId: Number
  }

  connect() {
    this.patternInputTarget.value = this.originalPatternValue
    this.matchSelectTarget.value = this.originalMatchTypeValue
    this.categorySelectTarget.value = this.originalCategoryIdValue
  }

  activatePattern(event) {
    if (this.patternInputTarget.classList.contains("hidden")) {
      this.patternDisplayTarget.classList.add("hidden")
      this.patternInputTarget.classList.remove("hidden")
      this.patternInputTarget.focus()
      this.patternInputTarget.select()
    }
  }

  activateMatch(event) {
    if (this.matchSelectTarget.classList.contains("hidden")) {
      this.matchDisplayTarget.classList.add("hidden")
      this.matchSelectTarget.classList.remove("hidden")
      this.matchSelectTarget.focus()
    }
  }

  activateCategory(event) {
    if (this.categorySelectTarget.classList.contains("hidden")) {
      this.categoryDisplayTarget.classList.add("hidden")
      this.categorySelectTarget.classList.remove("hidden")
      this.categorySelectTarget.focus()
    }
  }

  checkDirty() {
    const dirty =
      this.patternInputTarget.value !== this.originalPatternValue ||
      this.matchSelectTarget.value !== this.originalMatchTypeValue ||
      String(this.categorySelectTarget.value) !== String(this.originalCategoryIdValue)

    if (dirty) {
      this.saveBtnTarget.classList.remove("hidden")
      this.cancelBtnTarget.classList.remove("hidden")
    } else {
      this.saveBtnTarget.classList.add("hidden")
      this.cancelBtnTarget.classList.add("hidden")
    }
  }

  async save(event) {
    event.preventDefault()
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    const body = new URLSearchParams({
      "category_rule[pattern]": this.patternInputTarget.value,
      "category_rule[match_type]": this.matchSelectTarget.value,
      "category_rule[category_id]": this.categorySelectTarget.value,
      "_method": "patch"
    })

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: body.toString()
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        this.cancel()
      }
    } catch (error) {
      console.error("Failed to save rule:", error)
      this.cancel()
    }
  }

  cancel(event) {
    if (event) event.preventDefault()

    // Restore display elements
    this.patternInputTarget.value = this.originalPatternValue
    this.matchSelectTarget.value = this.originalMatchTypeValue
    this.categorySelectTarget.value = this.originalCategoryIdValue

    this.patternInputTarget.classList.add("hidden")
    this.patternDisplayTarget.classList.remove("hidden")

    this.matchSelectTarget.classList.add("hidden")
    this.matchDisplayTarget.classList.remove("hidden")

    this.categorySelectTarget.classList.add("hidden")
    this.categoryDisplayTarget.classList.remove("hidden")

    this.saveBtnTarget.classList.add("hidden")
    this.cancelBtnTarget.classList.add("hidden")
  }
}
