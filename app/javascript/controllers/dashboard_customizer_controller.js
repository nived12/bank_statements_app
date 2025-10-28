import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "toggle"]
  static values = { widgets: Array }

  connect() {
    this.widgets = this.widgetsValue || []
    console.log("Dashboard Customizer Controller connected", { widgets: this.widgets, hasModal: this.hasModalTarget })
  }

  openModal() {
    console.log("openModal called")
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
    } else {
      console.error("Modal target not found")
    }
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
  }

  toggleWidget(event) {
    const widgetId = event.currentTarget.dataset.widgetId
    const isChecked = event.currentTarget.checked
    
    // Find and update widget
    const widget = this.widgets.find(w => w.id === widgetId)
    if (widget) {
      widget.enabled = isChecked
      
      // Ensure at least 3 widgets are enabled
      const enabledCount = this.widgets.filter(w => w.enabled).length
      if (enabledCount < 3) {
        event.currentTarget.checked = true
        widget.enabled = true
        this.showError("Debe tener al menos 3 widgets habilitados")
        return
      }
    }
  }

  async saveLayout() {
    try {
      const response = await fetch(window.location.pathname + "/layout", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ widgets: this.widgets })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        this.showError("Error al guardar el diseño")
      }
    } catch (error) {
      console.error("Error saving layout:", error)
      this.showError("Error al guardar el diseño")
    }
  }

  showError(message) {
    if (window.showToast) {
      window.showToast(message, "error")
    } else {
      alert(message)
    }
  }
}

