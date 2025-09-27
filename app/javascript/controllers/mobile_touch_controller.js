import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["swipeable", "pullToRefresh"]
  static values = { 
    swipeThreshold: Number,
    pullThreshold: Number,
    refreshUrl: String 
  }

  connect() {
    this.swipeThresholdValue = this.swipeThresholdValue || 50
    this.pullThresholdValue = this.pullThresholdValue || 80
    
    this.setupTouchEvents()
    this.setupPullToRefresh()
  }

  setupTouchEvents() {
    this.swipeableTargets.forEach(element => {
      element.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
      element.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
      element.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false })
    })
  }

  setupPullToRefresh() {
    if (this.hasPullToRefreshTarget) {
      this.pullToRefreshTarget.addEventListener('touchstart', this.handlePullStart.bind(this), { passive: false })
      this.pullToRefreshTarget.addEventListener('touchmove', this.handlePullMove.bind(this), { passive: false })
      this.pullToRefreshTarget.addEventListener('touchend', this.handlePullEnd.bind(this), { passive: false })
    }
  }

  // Touch Start
  handleTouchStart(e) {
    this.touchStartX = e.touches[0].clientX
    this.touchStartY = e.touches[0].clientY
    this.touchStartTime = Date.now()
    this.isSwipe = false
  }

  // Touch Move
  handleTouchMove(e) {
    if (!this.touchStartX || !this.touchStartY) return

    const touchCurrentX = e.touches[0].clientX
    const touchCurrentY = e.touches[0].clientY
    const diffX = this.touchStartX - touchCurrentX
    const diffY = this.touchStartY - touchCurrentY

    // Determine if this is a swipe gesture
    if (Math.abs(diffX) > Math.abs(diffY)) {
      this.isSwipe = true
      // Prevent default scrolling for horizontal swipes
      if (Math.abs(diffX) > 10) {
        e.preventDefault()
      }
    }
  }

  // Touch End
  handleTouchEnd(e) {
    if (!this.touchStartX || !this.touchStartY) return

    const touchEndX = e.changedTouches[0].clientX
    const touchEndY = e.changedTouches[0].clientY
    const diffX = this.touchStartX - touchEndX
    const diffY = this.touchStartY - touchEndY
    const diffTime = Date.now() - this.touchStartTime

    // Reset touch coordinates
    this.touchStartX = null
    this.touchStartY = null

    // Only process if it's a quick gesture (less than 300ms)
    if (diffTime > 300) return

    if (this.isSwipe && Math.abs(diffX) > this.swipeThresholdValue) {
      // Horizontal swipe detected
      if (diffX > 0) {
        this.handleSwipeLeft(e.target)
      } else {
        this.handleSwipeRight(e.target)
      }
    } else if (!this.isSwipe && Math.abs(diffY) > this.swipeThresholdValue) {
      // Vertical swipe detected
      if (diffY > 0) {
        this.handleSwipeUp(e.target)
      } else {
        this.handleSwipeDown(e.target)
      }
    }
  }

  // Swipe Handlers
  handleSwipeLeft(element) {
    this.dispatch('swipeLeft', { target: element })
  }

  handleSwipeRight(element) {
    this.dispatch('swipeRight', { target: element })
  }

  handleSwipeUp(element) {
    this.dispatch('swipeUp', { target: element })
  }

  handleSwipeDown(element) {
    this.dispatch('swipeDown', { target: element })
  }

  // Pull to Refresh
  handlePullStart(e) {
    this.pullStartY = e.touches[0].clientY
    this.pullCurrentY = e.touches[0].clientY
    this.isPulling = false
  }

  handlePullMove(e) {
    if (!this.pullStartY) return

    this.pullCurrentY = e.touches[0].clientY
    const pullDistance = this.pullCurrentY - this.pullStartY

    // Only allow pull to refresh when at the top of the page
    if (window.scrollY === 0 && pullDistance > 0) {
      this.isPulling = true
      
      // Add visual feedback
      this.updatePullIndicator(pullDistance)
      
      // Prevent default scrolling
      if (pullDistance > 20) {
        e.preventDefault()
      }
    }
  }

  handlePullEnd(e) {
    if (!this.isPulling || !this.pullStartY) return

    const pullDistance = this.pullCurrentY - this.pullStartY
    
    if (pullDistance > this.pullThresholdValue) {
      this.triggerRefresh()
    } else {
      this.resetPullIndicator()
    }

    // Reset pull state
    this.pullStartY = null
    this.pullCurrentY = null
    this.isPulling = false
  }

  updatePullIndicator(distance) {
    const indicator = document.getElementById('pull-to-refresh-indicator')
    if (indicator) {
      const progress = Math.min(distance / this.pullThresholdValue, 1)
      indicator.style.transform = `translateY(${distance * 0.5}px)`
      indicator.style.opacity = progress
    }
  }

  resetPullIndicator() {
    const indicator = document.getElementById('pull-to-refresh-indicator')
    if (indicator) {
      indicator.style.transform = 'translateY(-100%)'
      indicator.style.opacity = '0'
    }
  }

  triggerRefresh() {
    this.dispatch('refresh')
    
    if (this.refreshUrlValue) {
      // Reload the page or fetch new data
      window.location.reload()
    }
  }

  // Utility method to dispatch custom events
  dispatch(eventName, detail = {}) {
    const event = new CustomEvent(`mobile:${eventName}`, {
      detail: detail,
      bubbles: true,
      cancelable: true
    })
    this.element.dispatchEvent(event)
  }
}
