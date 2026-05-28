import { Controller } from "@hotwired/stimulus"

/**
 * A transaction row's category trigger. The actual dropdown lives in the shared
 * `category-panel` controller (rendered once per page) and is reached via a Stimulus outlet,
 * so the dropdown markup is not duplicated into every row.
 */
export default class extends Controller {
  static targets = ["trigger"]
  static outlets = ["category-panel"]
  static values = { url: String, currentCategoryId: String }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.hasCategoryPanelOutlet) return
    this.categoryPanelOutlet.toggle(this)
  }

  async selectCategory(categoryId) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ category_id: categoryId || null })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Failed to update category:", error)
    }
  }
}
