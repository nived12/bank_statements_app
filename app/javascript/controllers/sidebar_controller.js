import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  connect() {
    this.setActiveNavItem()
  }

  setActiveNavItem() {
    // Get current path
    const currentPath = window.location.pathname

    // Find all sidebar nav items
    const navItems = document.querySelectorAll('.sidebar-nav-item')

    // Remove active class from all nav items
    navItems.forEach(item => {
      item.classList.remove('active')
    })

    // Find matching nav item and add active class
    navItems.forEach(item => {
      const href = item.getAttribute('href')
      if (href && this.isCurrentPath(href, currentPath)) {
        item.classList.add('active')
      }
    })
  }

  isCurrentPath(href, currentPath) {
    // Extract the controller/action from href
    const url = new URL(href, window.location.origin)
    const pathSegments = url.pathname.split('/').filter(segment => segment !== '')

    // Extract controller and action from current path
    const currentSegments = currentPath.split('/').filter(segment => segment !== '')

    // Match controller (usually the first segment after locale)
    if (pathSegments.length >= 2 && currentSegments.length >= 2) {
      return pathSegments[1] === currentSegments[1]
    }

    return false
  }
}
