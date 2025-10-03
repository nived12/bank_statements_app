import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "content"]
  static values = { 
    open: Boolean,
    parentModal: String 
  }

  connect() {
    // Listen for turbo-frame loads to show modal
    this.element.addEventListener("turbo:frame-load", (event) => {
      if (event.target.id === this.modalTarget.id) {
        this.show()
      }
    })

    // Listen for turbo-stream events to handle modal updates
    document.addEventListener("turbo:before-stream-render", (event) => {
      if (event.detail.newStream.action === "replace" && 
          event.detail.newStream.target.includes("modal")) {
        this.handleModalUpdate(event)
      }
    })
  }

  show() {
    this.openValue = true
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.style.display = "block"
    
    // Add animation
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "translateY(0%)"
    }
  }

  hide() {
    this.openValue = false
    this.modalTarget.classList.add("hidden")
    this.modalTarget.style.display = "none"
    
    // Reset animation
    if (this.hasContentTarget) {
      this.contentTarget.style.transform = "translateY(100%)"
    }
  }

  // Handle navigation to subcategory modal
  navigateToSubcategory(event) {
    event.preventDefault()
    
    const subcategoryId = event.currentTarget.dataset.subcategoryId
    const subcategoryName = event.currentTarget.dataset.subcategoryName
    const parentCategoryId = event.currentTarget.dataset.parentCategoryId
    
    // Store parent modal state
    this.parentModalValue = this.modalTarget.id
    
    // Hide current modal
    this.hide()
    
    // Load subcategory modal content
    const subcategoryModal = document.getElementById("subcategoryEditModal")
    if (subcategoryModal) {
      subcategoryModal.style.display = "block"
      subcategoryModal.classList.remove("hidden")
      
      // Populate subcategory form
      this.populateSubcategoryForm(subcategoryId, subcategoryName, parentCategoryId)
    }
  }

  // Handle navigation back to parent modal
  navigateBackToParent() {
    // Hide subcategory modal
    const subcategoryModal = document.getElementById("subcategoryEditModal")
    if (subcategoryModal) {
      subcategoryModal.classList.add("hidden")
      subcategoryModal.style.display = "none"
    }
    
    // Show parent modal
    if (this.parentModalValue) {
      const parentModal = document.getElementById(this.parentModalValue)
      if (parentModal) {
        parentModal.style.display = "block"
        parentModal.classList.remove("hidden")
        
        const parentContent = parentModal.querySelector(".mobile-edit-content")
        if (parentContent) {
          parentContent.style.transform = "translateY(0%)"
        }
      }
    }
    
    // Clear parent modal reference
    this.parentModalValue = ""
  }

  // Handle modal updates from turbo-streams
  handleModalUpdate(event) {
    // If we're in a subcategory modal and the parent category is being updated,
    // navigate back to the parent modal
    const subcategoryModal = document.getElementById("subcategoryEditModal")
    const isSubcategoryModalOpen = subcategoryModal && !subcategoryModal.classList.contains("hidden")
    
    if (isSubcategoryModalOpen && event.detail.newStream.target.includes("mobile-category-")) {
      // Parent category is being updated, navigate back to parent modal
      setTimeout(() => {
        this.navigateBackToParent()
      }, 100)
    }
  }

  // Populate subcategory form (moved from inline JavaScript)
  populateSubcategoryForm(subcategoryId, subcategoryName, parentCategoryId) {
    const nameInput = document.getElementById("subcategoryNameInput")
    const parentSelect = document.getElementById("subcategoryParentSelect")
    
    if (nameInput) {
      nameInput.value = subcategoryName
    }
    
    if (parentSelect) {
      // Fetch parent categories for dropdown
      fetch(`/${window.location.pathname.split('/')[1]}/categories.json`)
        .then(response => response.json())
        .then(data => {
          parentSelect.innerHTML = ""
          
          // Add current parent as selected option
          const currentParent = data.find(cat => cat.id === parentCategoryId)
          if (currentParent) {
            const option = document.createElement("option")
            option.value = parentCategoryId
            option.textContent = currentParent.name
            option.selected = true
            parentSelect.appendChild(option)
          }
          
          // Add other parent categories
          data.filter(cat => cat.parent_id === null && cat.id !== parentCategoryId)
            .forEach(category => {
              const option = document.createElement("option")
              option.value = category.id
              option.textContent = category.name
              parentSelect.appendChild(option)
            })
        })
        .catch(error => {
          console.error("Error fetching categories:", error)
          parentSelect.innerHTML = `<option value="${parentCategoryId}" selected>Current Parent</option>`
        })
    }
  }

  // Handle form submission
  submitForm(event) {
    event.preventDefault()
    
    const form = event.target
    const saveButton = form.querySelector('button[type="submit"]')
    
    if (saveButton) {
      // Show loading state
      saveButton.disabled = true
      saveButton.innerHTML = `
        <svg class="w-5 h-5 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
      `
    }
    
    // Submit form via Turbo
    form.requestSubmit()
  }
}
