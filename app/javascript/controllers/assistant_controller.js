import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "messages", "typingIndicator", "submitButton", "emptyState"]
  static values  = { conversationId: Number }

  connect() {
    this.scrollToBottom()
    this.#autoResizeInput()
  }

  // Intercept form submit: add optimistic user bubble, show typing indicator
  submit(event) {
    const content = this.inputTarget.value.trim()
    if (!content) {
      event.preventDefault()
      return
    }

    this.#hideEmptyState()
    this.#appendOptimisticBubble(content)
    this.#showTypingIndicator()
    this.#clearInput()
    this.#disableSubmit()
    this.scrollToBottom()

    // Let Turbo handle the actual POST — do not duplicate fetch
  }

  // Called after Turbo Stream appends content
  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  // Quick-reply chip: fill composer with preset text
  fill(event) {
    const text = event.params.text
    if (!text || !this.hasInputTarget) return
    this.inputTarget.value = text
    this.inputTarget.focus()
    this.#triggerResize()
  }

  // Cmd/Ctrl+Enter submits, Enter adds newline (default)
  keydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  // Re-enable submit button once Turbo Stream response arrives
  // (listen on turbo:stream-render on the messages container)
  turboStreamRendered() {
    this.#enableSubmit()
    this.scrollToBottom()
  }

  // ── Private helpers ─────────────────────────────────────────────────

  #appendOptimisticBubble(content) {
    if (!this.hasMessagesTarget) return
    const now = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    const escaped = this.#escapeHtml(content).replace(/\n/g, "<br>")
    const div = document.createElement("div")
    div.className = "flex justify-end"
    div.id = "optimistic-bubble"
    div.innerHTML = `
      <div class="max-w-[80%] sm:max-w-[70%]">
        <div class="bg-indigo-600 text-white rounded-2xl rounded-tr-sm px-4 py-3 text-sm leading-relaxed shadow-sm">${escaped}</div>
        <p class="text-xs text-slate-400 mt-1 text-right pr-1">${now}</p>
      </div>
    `
    // Insert before typing indicator
    const indicator = document.getElementById("typing-indicator")
    this.messagesTarget.insertBefore(div, indicator)
  }

  #showTypingIndicator() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.classList.remove("hidden")
    }
  }

  #hideEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.remove()
    }
    const el = document.getElementById("empty-state")
    if (el) el.remove()
  }

  #clearInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.#triggerResize()
    }
  }

  #disableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  #enableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
    // Remove optimistic bubble (real pair was appended by server)
    const optimistic = document.getElementById("optimistic-bubble")
    if (optimistic) optimistic.remove()
  }

  #autoResizeInput() {
    if (!this.hasInputTarget) return
    this.inputTarget.addEventListener("input", () => this.#triggerResize())
  }

  #triggerResize() {
    if (!this.hasInputTarget) return
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = Math.min(el.scrollHeight, 160) + "px"
  }

  #escapeHtml(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}
