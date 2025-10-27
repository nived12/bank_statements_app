import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigateBack(event) {
    // Add a class to trigger reverse transition animation
    document.documentElement.classList.add("transitioning-back")

    // Remove the class after navigation completes
    setTimeout(() => {
      document.documentElement.classList.remove("transitioning-back")
    }, 500)
  }
}
