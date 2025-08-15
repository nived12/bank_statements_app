import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
application.warnings = false

// Add error handling for controller connections
application.handleError = (error, controller, identifier) => {
  console.error(`Error in controller ${identifier}:`, error)
}

// Make Stimulus available globally for debugging
window.Stimulus = application

export { application }
