import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    accessToken: String,
    callbackUrl: String,
    environment: { type: String, default: "sandbox" }
  }

  connect() {
    this.loadBelvoScript()
  }

  disconnect() {
    // Clean up widget if needed
  }

  loadBelvoScript() {
    if (window.belvoSDK) {
      this.initializeWidget()
      return
    }

    const script = document.createElement("script")
    script.src = "https://cdn.belvo.io/belvo-widget-1-stable.js"
    script.async = true
    script.onload = () => this.initializeWidget()
    script.onerror = () => this.handleLoadError()
    document.head.appendChild(script)
  }

  initializeWidget() {
    if (!window.belvoSDK) {
      this.handleLoadError()
      return
    }

    window.belvoSDK.createWidget(this.accessTokenValue, {
      locale: document.documentElement.lang || "es",
      company_name: "Vittio",
      callback: (link, institution) => this.handleSuccess(link, institution),
      onExit: (data) => this.handleExit(data),
      onEvent: (event) => this.handleEvent(event),
    }).build()
  }

  handleSuccess(link, institution) {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.callbackUrlValue

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const fields = {
      "link_id": link,
      "institution": institution,
      "authenticity_token": csrfToken
    }

    Object.entries(fields).forEach(([name, value]) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    })

    document.body.appendChild(form)
    form.submit()
  }

  handleExit(_data) {
    this.closeModal()
  }

  handleEvent(event) {
    console.log("Belvo widget event:", event)
  }

  handleLoadError() {
    const container = this.element
    container.innerHTML = `<div class="p-6 text-center text-red-600">
      <p>Failed to load bank connection widget. Please try again.</p>
    </div>`
  }

  closeModal() {
    const modal = this.element.closest(".modal-overlay")
    if (modal) {
      modal.classList.add("hidden")
      document.body.style.overflow = ""
    }
  }
}
