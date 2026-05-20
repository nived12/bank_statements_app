import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "messages", "typingIndicator", "submitButton", "emptyState"]
  static values  = { conversationId: Number }

  connect() {
    this.scrollToBottom()
    this.#autoResizeInput()
  }

  // Intercept form submit: capture content, show optimistic bubble, POST manually.
  // We must call event.preventDefault() and POST via fetch because #clearInput()
  // empties the textarea before Turbo would serialize it — sending content:"" otherwise.
  submit(event) {
    const content = this.inputTarget.value.trim()
    if (!content) {
      event.preventDefault()
      return
    }

    event.preventDefault()

    this.#hideEmptyState()
    this.#appendOptimisticBubble(content)
    this.#showTypingIndicator()
    this.#clearInput()
    this.#disableSubmit()
    requestAnimationFrame(() => this.scrollToBottom())

    const body = new FormData()
    body.append("content", content)

    const convId = this.formTarget.querySelector("[name='conversation_id']")?.value
    if (convId) body.append("conversation_id", convId)

    const csrf = document.querySelector("meta[name='csrf-token']")?.content

    fetch(this.formTarget.action, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrf,
      },
      body,
    })
      .then(async (res) => {
        const html = await res.text()
        await Turbo.renderStreamMessage(html)
        this.#enableSubmit()
      })
      .catch(() => this.#enableSubmit())
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
    const now = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })
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
    // Append at the true end of #messages (typing indicator is now outside #messages)
    this.messagesTarget.append(div)
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
