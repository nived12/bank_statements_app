import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    // Ensure menu is closed when controller connects
    this.closeMenu()
    
    // Add event listeners
    this.addEventListeners()
    
    // Log connection for debugging
    console.log('Language switcher controller connected')
  }

  disconnect() {
    // Clean up event listeners
    this.removeEventListeners()
    
    // Log disconnection for debugging
    console.log('Language switcher controller disconnected')
  }

  addEventListeners() {
    // Close menu when clicking outside
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
    document.addEventListener('click', this.outsideClickHandler)
    
    // Close menu with Escape key
    this.escapeKeyHandler = this.handleEscapeKey.bind(this)
    document.addEventListener('keydown', this.escapeKeyHandler)
    
    // Close menu when navigating away (for Turbo/Hotwire)
    this.turboBeforeVisitHandler = this.closeMenu.bind(this)
    this.turboVisitHandler = this.closeMenu.bind(this)
    document.addEventListener('turbo:before-visit', this.turboBeforeVisitHandler)
    document.addEventListener('turbo:visit', this.turboVisitHandler)
    
    // Close menu when page is about to unload
    this.beforeUnloadHandler = this.closeMenu.bind(this)
    window.addEventListener('beforeunload', this.beforeUnloadHandler)
    
    // Close menu when page visibility changes
    this.visibilityChangeHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener('visibilitychange', this.visibilityChangeHandler)
    
    // Close menu when window loses focus
    this.blurHandler = this.closeMenu.bind(this)
    window.addEventListener('blur', this.blurHandler)
  }

  removeEventListeners() {
    if (this.outsideClickHandler) {
      document.removeEventListener('click', this.outsideClickHandler)
    }
    if (this.escapeKeyHandler) {
      document.removeEventListener('keydown', this.escapeKeyHandler)
    }
    if (this.turboBeforeVisitHandler) {
      document.removeEventListener('turbo:before-visit', this.turboBeforeVisitHandler)
    }
    if (this.turboVisitHandler) {
      document.removeEventListener('turbo:visit', this.turboVisitHandler)
    }
    if (this.beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this.beforeUnloadHandler)
    }
    if (this.visibilityChangeHandler) {
      document.removeEventListener('visibilitychange', this.visibilityChangeHandler)
    }
    if (this.blurHandler) {
      window.removeEventListener('blur', this.blurHandler)
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    // Small delay to prevent race conditions
    setTimeout(() => {
      const isHidden = this.menuTarget.classList.contains('hidden')
      if (isHidden) {
        this.openMenu()
      } else {
        this.closeMenu()
      }
    }, 10)
  }

  openMenu() {
    // Close any other open language switcher menus first
    this.closeAllOtherMenus()
    
    this.menuTarget.classList.remove('hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'true')
    
    console.log('Language menu opened')
  }

  closeMenu() {
    this.menuTarget.classList.add('hidden')
    this.buttonTarget.setAttribute('aria-expanded', 'false')
    
    console.log('Language menu closed')
  }

  closeAllOtherMenus() {
    // Find all other language switcher menus and close them
    const allMenus = document.querySelectorAll('[data-language-switcher-target="menu"]')
    allMenus.forEach(menu => {
      if (menu !== this.menuTarget) {
        menu.classList.add('hidden')
        const button = menu.parentElement.querySelector('[data-language-switcher-target="button"]')
        if (button) {
          button.setAttribute('aria-expanded', 'false')
        }
      }
    })
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeMenu()
    }
  }

  handleEscapeKey(event) {
    if (event.key === 'Escape') {
      this.closeMenu()
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.closeMenu()
    }
  }
}
