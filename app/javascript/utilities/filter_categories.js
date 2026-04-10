// Shared client-side category search filter for Stimulus controllers.
// Requires the controller to declare `categorySearch` and `categoryList` targets.
export function filterCategories(controller) {
  if (!controller.hasCategorySearchTarget || !controller.hasCategoryListTarget) return

  const query = controller.categorySearchTarget.value.toLowerCase().trim()
  const labels = controller.categoryListTarget.querySelectorAll("label[data-category-name]")

  if (!query) {
    labels.forEach(label => (label.style.display = ""))
    return
  }

  const matchedParentNames = new Set()
  labels.forEach(label => {
    const name = (label.dataset.categoryName || "").toLowerCase()
    if (name.includes(query) && label.dataset.categoryParentName) {
      matchedParentNames.add(label.dataset.categoryParentName.toLowerCase())
    }
  })

  labels.forEach(label => {
    const name = (label.dataset.categoryName || "").toLowerCase()
    const isMatch = name.includes(query)
    const isParentOfMatch = matchedParentNames.has(name)
    label.style.display = (isMatch || isParentOfMatch) ? "" : "none"
  })
}
