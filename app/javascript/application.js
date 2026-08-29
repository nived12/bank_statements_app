// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import flatpickr from "flatpickr"

// Make flatpickr globally available
window.flatpickr = flatpickr;
