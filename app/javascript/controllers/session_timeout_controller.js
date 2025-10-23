import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    timeoutMinutes: { type: Number, default: 30 },
    warningMinutes: { type: Number, default: 5 }
  }
  
  static targets = ["warning", "countdown"]

  connect() {
    // Debug logging to see if controller is connecting
    console.log('Session timeout controller connecting...', {
      hostname: window.location.hostname,
      isProduction: this.isProduction()
    })
    
    // TEMPORARILY DISABLE ALL SESSION TIMEOUT FUNCTIONALITY
    console.log('Session timeout DISABLED for debugging')
    return
    
    // Prevent multiple instances from running
    if (window.sessionTimeoutInitialized) {
      console.log('Session timeout already initialized, skipping')
      return
    }
    
    // Only initialize session timeout in production environment
    if (this.isProduction()) {
      console.log('Initializing session timeout for production')
      window.sessionTimeoutInitialized = true
      this.initializeSession()
      this.setupActivityTracking()
      this.startTimeoutCheck()
    } else {
      console.log('Skipping session timeout initialization for development')
    }
  }

  disconnect() {
    this.clearTimers()
    window.sessionTimeoutInitialized = false
  }

  isProduction() {
    // Check if we're in production environment
    // Disable session timeout in development and test environments
    const hostname = window.location.hostname
    const isLocalNetwork = hostname.includes('192.168.') || 
                          hostname.includes('10.0.') || 
                          hostname.includes('172.16.') ||
                          hostname === 'localhost' || 
                          hostname === '127.0.0.1' ||
                          hostname.includes('.test') ||
                          hostname.includes('.local')
    
    console.log('Production check:', {
      hostname,
      isLocalNetwork,
      protocol: window.location.protocol,
      isProduction: !isLocalNetwork && window.location.protocol !== 'file:'
    })
    
    return !isLocalNetwork && window.location.protocol !== 'file:'
  }

  initializeSession() {
    // Initialize session storage with current timestamp if not exists
    if (!sessionStorage.getItem('last_activity')) {
      sessionStorage.setItem('last_activity', Date.now().toString())
    }
  }

  setupActivityTracking() {
    // Track user activity events with more conservative throttling
    const events = ['mousedown', 'keypress', 'click', 'touchstart']
    
    let lastHeartbeat = 0
    const heartbeatThrottle = 300000 // Only send heartbeat every 5 minutes (300 seconds)
    
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

    // Track when the page becomes visible again (user returns to tab)
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) {
        const now = Date.now()
        const lastActivity = sessionStorage.getItem('last_activity')
        if (!lastActivity || (now - parseInt(lastActivity)) > 60000) { // Only if inactive for 1+ minute
          this.updateActivity()
        }
      }
    })
  }

  updateActivity() {
    console.log('updateActivity called')
    // Update local session storage
    sessionStorage.setItem('last_activity', Date.now().toString())
    
    // Only send heartbeat if we're on a page that requires authentication
    if (document.querySelector('meta[name="csrf-token"]')) {
      console.log('Sending heartbeat request')
      // Send heartbeat to keep session alive
      fetch('/session/heartbeat', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Content-Type': 'application/json'
        }
      }).catch((error) => {
        console.log('Heartbeat request failed:', error)
      })
    }
  }

  startTimeoutCheck() {
    this.checkTimeout()
    this.timer = setInterval(() => this.checkTimeout(), 60000) // Check every 60 seconds instead of 30
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
