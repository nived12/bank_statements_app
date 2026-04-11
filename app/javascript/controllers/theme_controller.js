import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { preference: String }

  connect() {
    this.applyTheme(this.preferenceValue || "system")
    this.setupSystemListener()
    this.updateToggleUI()
  }

  disconnect() {
    this.removeSystemListener()
  }

  setLight() {
    this.saveAndApply("light")
  }

  setDark() {
    this.saveAndApply("dark")
  }

  setSystem() {
    this.saveAndApply("system")
  }

  // ── Private ────────────────────────────────────────────────

  saveAndApply(preference) {
    this.preferenceValue = preference
    this.applyTheme(preference)
    this.updateToggleUI()
    this.persistPreference(preference)
  }

  applyTheme(preference) {
    const isDark =
      preference === "dark" ||
      (preference === "system" && this.systemPrefersDark())

    document.documentElement.classList.toggle("dark", isDark)
    this.dispatchThemeChanged(isDark ? "dark" : "light")
  }

  systemPrefersDark() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
  }

  setupSystemListener() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemChangeHandler = () => {
      if (this.preferenceValue === "system") {
        this.applyTheme("system")
        this.updateToggleUI()
      }
    }
    this.mediaQuery.addEventListener("change", this.systemChangeHandler)
  }

  removeSystemListener() {
    if (this.mediaQuery && this.systemChangeHandler) {
      this.mediaQuery.removeEventListener("change", this.systemChangeHandler)
    }
  }

  updateToggleUI() {
    const pref = this.preferenceValue || "system"
    // Find all theme toggle buttons in the document and mark the active one
    document.querySelectorAll("[data-theme-mode]").forEach(btn => {
      const isActive = btn.dataset.themeMode === pref
      btn.classList.toggle("text-blue-500", isActive)
      btn.classList.toggle("bg-blue-50", isActive)
      btn.classList.toggle("dark:text-blue-400", isActive)
      btn.classList.toggle("dark:bg-blue-900/30", isActive)
      btn.setAttribute("aria-pressed", isActive.toString())
    })
  }

  persistPreference(preference) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    fetch("/user_settings", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken || "",
      },
      body: JSON.stringify({ theme: preference }),
    }).catch(() => {
      // Silently fail — the preference is still applied locally
    })
  }

  dispatchThemeChanged(resolvedTheme) {
    document.dispatchEvent(
      new CustomEvent("theme:changed", { detail: { theme: resolvedTheme } })
    )
  }
}
