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
    
    // Find and update widget (widgets use string keys for id)
    const widget = this.widgets.find(w => w.id === widgetId || w["id"] === widgetId)
    if (widget) {
      widget.enabled = isChecked
      
      // Ensure at least 3 widgets are enabled
      const enabledCount = this.widgets.filter(w => w.enabled === true).length
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
      // Ensure at least 3 widgets are enabled before saving
      const enabledCount = this.widgets.filter(w => w.enabled === true).length
      if (enabledCount < 3) {
        this.showError("Debe tener al menos 3 widgets habilitados")
        return
      }

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
        const errorData = await response.json().catch(() => ({ error: "Error al guardar el diseño" }))
        this.showError(errorData.error || "Error al guardar el diseño")
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

