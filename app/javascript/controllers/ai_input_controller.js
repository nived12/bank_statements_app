import { Controller } from "@hotwired/stimulus"

/**
 * AI Input controller — voice (Chrome Web Speech API) + receipt image upload.
 *
 * Voice: only shown when SpeechRecognition is available (Chrome/Edge).
 * Image: file picker → base64 encode → POST parse_image → pre-fill form.
 * Both paths pre-fill amount, description, type, date, category but never submit.
 */
export default class extends Controller {
  static targets = ["micButton", "fileInput", "statusLabel"]
  static values = {
    voiceUrl: { type: String, default: "/transactions/parse_voice" },
    imageUrl: { type: String, default: "/transactions/parse_image" }
  }

  connect() {
    this._micActive = false
    this._recognition = null
    this._initSpeech()
  }

  disconnect() {
    if (this._recognition) this._recognition.abort()
  }

  // ── Speech ────────────────────────────────────────────────────────────────

  _initSpeech() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) {
      if (this.hasMicButtonTarget) this.micButtonTarget.classList.add("hidden")
      return
    }

    this._recognition = new SpeechRecognition()
    this._recognition.lang = "es-MX"
    this._recognition.continuous = false
    this._recognition.interimResults = false

    this._recognition.onresult = async (e) => {
      const transcript = e.results[0][0].transcript
      this._setStatus(this._t("processing"), "indigo")
      await this._parseVoice(transcript)
    }
    this._recognition.onerror = () => {
      this._setStatus(this._t("voiceError"))
      setTimeout(() => this._setStatus(""), 3000)
      this._setMicActive(false)
    }
    this._recognition.onend = () => this._setMicActive(false)
  }

  toggleMic() {
    if (!this._recognition) return
    if (this._micActive) {
      this._recognition.stop()
      this._setStatus("")
      this._setMicActive(false)
    } else {
      try {
        this._recognition.start()
        this._setStatus(this._t("listening"))
        this._setMicActive(true)
      } catch {
        this._setStatus(this._t("voiceError"))
        setTimeout(() => this._setStatus(""), 3000)
      }
    }
  }

  async _parseVoice(text) {
    try {
      const res = await fetch(this.voiceUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this._csrf() },
        body: JSON.stringify({ text })
      })
      if (res.status === 402) {
        const data = await res.json()
        this._setStatus(data.error || this._t("subscriptionRequired"), "amber")
        setTimeout(() => this._setStatus(""), 5000)
        return
      }
      if (!res.ok) throw new Error()
      this._applyResult(await res.json())
      this._setStatus("")
    } catch {
      this._setStatus(this._t("voiceError"), "red")
      setTimeout(() => this._setStatus(""), 3000)
    }
  }

  // ── Image ─────────────────────────────────────────────────────────────────

  async uploadFile() {
    const file = this.fileInputTarget.files[0]
    if (!file) return

    this._setStatus(this._t("readingReceipt"))
    try {
      const base64Full = await this._toBase64(file)
      const base64     = base64Full.split(",")[1]

      const res = await fetch(this.imageUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this._csrf() },
        body: JSON.stringify({ image: base64, mime_type: file.type })
      })
      if (res.status === 402) {
        const data = await res.json()
        this._setStatus(data.error || this._t("subscriptionRequired"), "amber")
        setTimeout(() => this._setStatus(""), 5000)
        return
      }
      if (!res.ok) throw new Error()
      this._applyResult(await res.json())
      this._setStatus("")
    } catch {
      this._setStatus(this._t("imageError"), "red")
      setTimeout(() => this._setStatus(""), 3000)
    } finally {
      this.fileInputTarget.value = ""
    }
  }

  // ── Pre-fill ──────────────────────────────────────────────────────────────

  _applyResult(data) {
    const form = this.element

    if (data.amount) {
      const amountEl = form.querySelector("[data-ai-amount]")
      if (amountEl) {
        amountEl.value = Math.abs(data.amount).toFixed(2)
        amountEl.dispatchEvent(new Event("input", { bubbles: true }))
      }
    }

    if (data.description) {
      const descEl = form.querySelector("[data-ai-description]")
      if (descEl) descEl.value = data.description
    }

    if (data.transaction_type) {
      const typeEl = form.querySelector("[data-ai-type]")
      if (typeEl) {
        typeEl.value = data.transaction_type
        typeEl.dispatchEvent(new Event("change", { bubbles: true }))
      }
    }

    if (data.date) {
      const dateEl = form.querySelector("[data-ai-date]")
      if (dateEl) dateEl.value = data.date
    }

    if (data.category_suggestion?.id) {
      const radio = form.querySelector(
        `input[name='transaction[category_id]'][value='${data.category_suggestion.id}']`
      )
      if (radio) {
        radio.checked = true
        radio.dispatchEvent(new Event("change", { bubbles: true }))
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _setStatus(msg, color = "indigo") {
    if (!this.hasStatusLabelTarget) return
    const el = this.statusLabelTarget
    el.textContent = msg
    el.className = el.className.replace(/\btext-\w+-\d+\b/g, "")
    const colorMap = { indigo: "text-indigo-600", red: "text-red-600", amber: "text-amber-600" }
    el.classList.add(colorMap[color] || "text-indigo-600")
  }

  _setMicActive(active) {
    this._micActive = active
    if (!this.hasMicButtonTarget) return
    if (active) {
      this.micButtonTarget.classList.add("bg-red-100", "text-red-600", "border-red-300")
      this.micButtonTarget.classList.remove("border-slate-300", "text-slate-600")
    } else {
      this.micButtonTarget.classList.remove("bg-red-100", "text-red-600", "border-red-300")
      this.micButtonTarget.classList.add("border-slate-300", "text-slate-600")
    }
  }

  _csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  _toBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload  = () => resolve(reader.result)
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }

  _t(key) {
    const map = {
      listening:     "Escuchando…",
      processing:    "Procesando…",
      readingReceipt:"Leyendo tu recibo…",
      voiceError:          "No pude entender. Intenta de nuevo.",
      imageError:          "No pude leer el recibo. Intenta de nuevo.",
      subscriptionRequired:"Función disponible en el plan Pro."
    }
    return map[key] || ""
  }
}
