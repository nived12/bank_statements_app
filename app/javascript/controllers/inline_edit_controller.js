import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "saveButton", "iconInput"]
  static values = { url: String }

  connect() {
    this.originalValue = this.inputTarget.value
    if (this.hasIconInputTarget) {
      this.originalIcon = this.iconInputTarget.value
    }
  }

  save() {
    const newValue = this.inputTarget.value.trim()
    const newIcon = this.hasIconInputTarget ? this.iconInputTarget.value : null

    // Check if nothing has changed
    const nameChanged = newValue !== this.originalValue && newValue !== ""
    const iconChanged = this.hasIconInputTarget && newIcon !== this.originalIcon

    if (!nameChanged && !iconChanged) {
      this.cancel()
      return
    }

    // Build category data - use original name if not changed, new name if changed
    const categoryData = { name: newValue || this.originalValue }
    if (newIcon) {
      categoryData.icon = newIcon
    }

    // Send PATCH request to update category
    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        category: categoryData
      })
    })
    .then(response => {
      if (response.ok) {
        // Redirect to categories list after successful update
        window.location.href = '/categories'
      } else {
        // Revert to original value on error
        this.cancel()
      }
    })
    .catch(() => {
      this.cancel()
    })
  }

  cancel() {
    this.inputTarget.value = this.originalValue
    this.hideSaveButton()
    this.inputTarget.blur()
  }

  showSaveButton() {
    const nameChanged = this.inputTarget.value !== this.originalValue
    const iconChanged = this.hasIconInputTarget && this.iconInputTarget.value !== this.originalIcon

    if (nameChanged || iconChanged) {
      this.saveButtonTarget.classList.remove('hidden')
    }
  }

  iconChanged() {
    // Called when icon is selected in the picker
    this.showSaveButton()
  }

  hideSaveButton() {
    this.saveButtonTarget.classList.add('hidden')
  }
}
