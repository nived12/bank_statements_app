import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "patternDisplay", "patternInput",
    "matchDisplay", "matchSelect",
    "categoryDisplay", "categorySelect",
    "categoryPicker", "categorySearchInput", "categoryOptionLabel",
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
    this.boundHandleClickOutside = this.handlePickerClickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClickOutside)
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
    if (this.categoryPickerTarget.classList.contains("hidden")) {
      const rect = this.categoryDisplayTarget.getBoundingClientRect()
      this.categoryPickerTarget.style.top = `${rect.bottom + 4}px`
      this.categoryPickerTarget.style.left = `${rect.left}px`

      this.categoryDisplayTarget.classList.add("hidden")
      this.categoryPickerTarget.classList.remove("hidden")
      this.categorySearchInputTarget.value = ""
      this.filterCategoryOptions()
      this.categorySearchInputTarget.focus()
      setTimeout(() => {
        document.addEventListener("click", this.boundHandleClickOutside)
      }, 100)
    }
  }

  handlePickerClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closePicker()
    }
  }

  closePicker() {
    this.categoryPickerTarget.classList.add("hidden")
    this.categoryDisplayTarget.classList.remove("hidden")
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  selectCategoryOption(event) {
    const radio = event.target
    const categoryId = radio.value
    const categoryName = radio.dataset.categoryName
    const parentName = radio.dataset.categoryParentName

    this.categorySelectTarget.value = categoryId

    let displayText = categoryName
    if (parentName) {
      displayText += ` <span class="text-xs text-slate-500">(${parentName})</span>`
      this.categoryDisplayTarget.innerHTML = displayText
    } else {
      this.categoryDisplayTarget.textContent = categoryName
    }

    this.closePicker()
    this.checkDirty()
  }

  filterCategoryOptions() {
    const query = this.categorySearchInputTarget.value.toLowerCase().trim()
    const labels = this.categoryOptionLabelTargets

    if (!query) {
      labels.forEach(label => label.style.display = "")
      return
    }

    const matchedIds = new Set()
    const matchedParentIds = new Set()

    labels.forEach(label => {
      const name = label.querySelector("span")?.textContent?.toLowerCase() || ""
      if (name.includes(query)) {
        matchedIds.add(label.dataset.categoryId)
        if (label.dataset.categoryParentId) matchedParentIds.add(label.dataset.categoryParentId)
      }
    })

    labels.forEach(label => {
      const id = label.dataset.categoryId
      const parentId = label.dataset.categoryParentId
      const show = matchedIds.has(id) || matchedParentIds.has(id) || (parentId && matchedIds.has(parentId))
      label.style.display = show ? "" : "none"
    })
  }

  stopPropagation(event) {
    event.stopPropagation()
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

    // Restore pattern
    this.patternInputTarget.value = this.originalPatternValue
    this.patternInputTarget.classList.add("hidden")
    this.patternDisplayTarget.classList.remove("hidden")

    // Restore match type
    this.matchSelectTarget.value = this.originalMatchTypeValue
    this.matchSelectTarget.classList.add("hidden")
    this.matchDisplayTarget.classList.remove("hidden")

    // Restore category
    this.categorySelectTarget.value = this.originalCategoryIdValue
    const originalId = String(this.originalCategoryIdValue)
    this.categoryOptionLabelTargets.forEach(label => {
      const radio = label.querySelector("input[type=radio]")
      if (radio) radio.checked = radio.value === originalId
    })
    this.closePicker()

    this.saveBtnTarget.classList.add("hidden")
    this.cancelBtnTarget.classList.add("hidden")
  }
}
