import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
application.warnings = false

// Make Stimulus available globally for debugging
window.Stimulus = application

export { application }
