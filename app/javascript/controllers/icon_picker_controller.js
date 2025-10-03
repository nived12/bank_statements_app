import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "iconButton", "pickerContainer", "iconDisplay"]
  static values = { selected: String }

  togglePicker() {
    if (this.hasPickerContainerTarget) {
      this.pickerContainerTarget.classList.toggle('hidden')
    }
  }

  select(event) {
    const iconName = event.params.icon

    // Update hidden input
    this.inputTarget.value = iconName

    // Update button states in grid
    this.iconButtonTargets.forEach(button => {
      const buttonIcon = button.dataset.iconName

      if (buttonIcon === iconName) {
        // Selected state
        button.classList.remove('border-slate-200', 'bg-white')
        button.classList.add('border-blue-500', 'bg-blue-50')

        const svg = button.querySelector('svg')
        if (svg) {
          svg.classList.remove('text-slate-600')
          svg.classList.add('text-blue-600')
        }
      } else {
        // Unselected state
        button.classList.remove('border-blue-500', 'bg-blue-50')
        button.classList.add('border-slate-200', 'bg-white')

        const svg = button.querySelector('svg')
        if (svg) {
          svg.classList.remove('text-blue-600')
          svg.classList.add('text-slate-600')
        }
      }
    })

    // Update the icon display button
    if (this.hasIconDisplayTarget) {
      this.updateIconDisplay(iconName)
    }

    // Hide picker after selection
    if (this.hasPickerContainerTarget) {
      this.pickerContainerTarget.classList.add('hidden')
    }

    // Update selected value
    this.selectedValue = iconName

    // Notify inline-edit controller that icon has changed
    const inlineEditController = this.application.getControllerForElementAndIdentifier(
      this.element.closest('[data-controller*="inline-edit"]'),
      'inline-edit'
    )
    if (inlineEditController) {
      inlineEditController.iconChanged()
    }
  }

  updateIconDisplay(iconName) {
    // Find the selected button in the picker to get its SVG
    const selectedButton = this.iconButtonTargets.find(btn => btn.dataset.iconName === iconName)

    if (selectedButton && this.iconDisplayTarget) {
      // Clone the SVG from the selected icon button
      const newSvg = selectedButton.querySelector('svg').cloneNode(true)

      // Preserve the display button's classes (use setAttribute for SVG)
      newSvg.setAttribute('class', 'w-5 h-5 text-blue-600')

      // Replace the old SVG with the new one
      const oldSvg = this.iconDisplayTarget.querySelector('svg')
      if (oldSvg) {
        this.iconDisplayTarget.replaceChild(newSvg, oldSvg)
      }
    }
  }
}
