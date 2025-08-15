import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    timeoutMinutes: { type: Number, default: 5 },
    warningMinutes: { type: Number, default: 1 }
  }
  
  static targets = ["warning", "countdown"]

  connect() {
    this.initializeSession()
    this.setupActivityTracking()
    this.startTimeoutCheck()
  }

  disconnect() {
    this.clearTimers()
  }

  initializeSession() {
    // Initialize session storage with current timestamp if not exists
    if (!sessionStorage.getItem('last_activity')) {
      sessionStorage.setItem('last_activity', Date.now().toString())
    }
  }

  setupActivityTracking() {
    // Track user activity events with throttling to avoid excessive requests
    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click']
    
    let lastHeartbeat = 0
    const heartbeatThrottle = 30000 // Only send heartbeat every 30 seconds
    
    events.forEach(event => {
      document.addEventListener(event, () => {
        const now = Date.now()
        if (now - lastHeartbeat > heartbeatThrottle) {
          this.updateActivity()
          lastHeartbeat = now
        } else {
          // Just update local storage without sending heartbeat
          sessionStorage.setItem('last_activity', now.toString())
        }
      }, { passive: true })
    })

    // Also track when the page becomes visible again (user returns to tab)
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) {
        this.updateActivity()
      }
    })
  }

  updateActivity() {
    // Update local session storage
    sessionStorage.setItem('last_activity', Date.now().toString())
    
    // Only send heartbeat if we're on a page that requires authentication
    if (document.querySelector('meta[name="csrf-token"]')) {
      // Send heartbeat to keep session alive
      fetch('/session/heartbeat', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Content-Type': 'application/json'
        }
      }).catch(() => {
        // Silently fail if heartbeat fails
      })
    }
  }

  startTimeoutCheck() {
    this.checkTimeout()
    this.timer = setInterval(() => this.checkTimeout(), 30000) // Check every 30 seconds
  }

  checkTimeout() {
    const lastActivity = sessionStorage.getItem('last_activity')
    if (!lastActivity) return

    const now = Date.now()
    const timeSinceActivity = now - parseInt(lastActivity)
    const timeoutMs = this.timeoutMinutesValue * 60 * 1000
    const warningMs = this.warningMinutesValue * 60 * 1000

    if (timeSinceActivity >= timeoutMs) {
      // Session expired, redirect to login
      this.expireSession()
    } else if (timeSinceActivity >= (timeoutMs - warningMs)) {
      // Show warning
      this.showWarning(timeoutMs - timeSinceActivity)
    } else {
      // Hide warning if it was showing
      this.hideWarning()
    }
  }

  showWarning(timeRemaining) {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.remove('hidden')
      
      if (this.hasCountdownTarget) {
        const minutes = Math.floor(timeRemaining / 60000)
        const seconds = Math.floor((timeRemaining % 60000) / 1000)
        this.countdownTarget.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`
      }
    }
  }

  hideWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.add('hidden')
    }
  }

  expireSession() {
    // Clear session storage
    sessionStorage.clear()
    
    // Redirect to login with expired message
    window.location.href = '/session/new?expired=true'
  }

  clearTimers() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  // Method to extend session when user clicks "Stay Logged In"
  extendSession() {
    this.updateActivity()
    this.hideWarning()
  }
}
