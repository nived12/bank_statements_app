import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "slide", "indicator"]

  connect() {
    this.currentIndex = 0
    this.totalSlides = this.slideTargets.length
    this.autoPlay = true
    this.autoPlayInterval = 5000 // 5 seconds

    // Initialize carousel
    this.initializeCarousel()
    this.updateIndicators()
    this.startAutoPlay()

    // Add touch event listeners
    this.addTouchListeners()

    // Add resize listener for responsive handling
    window.addEventListener('resize', this.handleResize.bind(this))
  }

  disconnect() {
    this.stopAutoPlay()
    window.removeEventListener('resize', this.handleResize.bind(this))
  }

  initializeCarousel() {
    // Set initial positions
    this.slideTargets.forEach((slide, index) => {
      slide.style.transform = `translateX(${index * 100}%)`
      slide.style.transition = 'transform 0.3s ease-in-out'
    })

    // Enable smooth scrolling behavior for container
    this.containerTarget.style.scrollBehavior = 'smooth'
  }

  goToSlide(index) {
    // Ensure index is within bounds
    if (index < 0) index = this.totalSlides - 1
    if (index >= this.totalSlides) index = 0

    this.currentIndex = index

    // Update slide positions
    this.slideTargets.forEach((slide, i) => {
      const offset = (i - this.currentIndex) * 100
      slide.style.transform = `translateX(${offset}%)`
    })

    this.updateIndicators()
    this.resetAutoPlay()
  }

  next() {
    this.goToSlide(this.currentIndex + 1)
  }

  previous() {
    this.goToSlide(this.currentIndex - 1)
  }

  updateIndicators() {
    if (this.hasIndicatorTarget) {
      this.indicatorTargets.forEach((indicator, index) => {
        if (index === this.currentIndex) {
          indicator.classList.add('active')
          indicator.setAttribute('aria-current', 'true')
        } else {
          indicator.classList.remove('active')
          indicator.setAttribute('aria-current', 'false')
        }
      })
    }
  }

  // Touch/swipe functionality
  addTouchListeners() {
    let startX = 0
    let currentX = 0
    let isDragging = false
    let startTime = 0

    const container = this.containerTarget

    // Mouse events for desktop testing
    container.addEventListener('mousedown', (e) => {
      this.handleTouchStart(e.clientX, e.timeStamp)
      e.preventDefault()
    })

    container.addEventListener('mousemove', (e) => {
      if (isDragging) {
        this.handleTouchMove(e.clientX)
        e.preventDefault()
      }
    })

    container.addEventListener('mouseup', (e) => {
      if (isDragging) {
        this.handleTouchEnd(e.clientX, e.timeStamp)
        e.preventDefault()
      }
    })

    // Touch events for mobile
    container.addEventListener('touchstart', (e) => {
      const touch = e.touches[0]
      this.handleTouchStart(touch.clientX, e.timeStamp)
    }, { passive: true })

    container.addEventListener('touchmove', (e) => {
      if (isDragging) {
        const touch = e.touches[0]
        this.handleTouchMove(touch.clientX)
      }
    }, { passive: true })

    container.addEventListener('touchend', (e) => {
      if (isDragging) {
        const touch = e.changedTouches[0]
        this.handleTouchEnd(touch.clientX, e.timeStamp)
      }
    }, { passive: true })

    const handleTouchStart = (clientX, timeStamp) => {
      startX = clientX
      currentX = clientX
      startTime = timeStamp
      isDragging = true
      this.stopAutoPlay()
    }

    const handleTouchMove = (clientX) => {
      if (!isDragging) return
      currentX = clientX
    }

    const handleTouchEnd = (clientX, timeStamp) => {
      if (!isDragging) return

      const diffX = startX - clientX
      const diffTime = timeStamp - startTime
      const velocity = Math.abs(diffX) / diffTime

      // Determine if swipe is significant enough
      const minSwipeDistance = 50
      const minVelocity = 0.3

      if (Math.abs(diffX) > minSwipeDistance || velocity > minVelocity) {
        if (diffX > 0) {
          this.next()
        } else {
          this.previous()
        }
      }

      isDragging = false
      this.startAutoPlay()
    }

    this.handleTouchStart = handleTouchStart
    this.handleTouchMove = handleTouchMove
    this.handleTouchEnd = handleTouchEnd
  }

  // Auto-play functionality
  startAutoPlay() {
    if (!this.autoPlay) return

    this.stopAutoPlay()
    this.autoPlayTimer = setInterval(() => {
      this.next()
    }, this.autoPlayInterval)
  }

  stopAutoPlay() {
    if (this.autoPlayTimer) {
      clearInterval(this.autoPlayTimer)
      this.autoPlayTimer = null
    }
  }

  resetAutoPlay() {
    if (this.autoPlay) {
      this.stopAutoPlay()
      this.startAutoPlay()
    }
  }

  // Handle window resize
  handleResize() {
    // Recalculate positions on resize
    this.goToSlide(this.currentIndex)
  }

  // Action methods for stimulus
  goToSlideAction(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.goToSlide(index)
  }

  nextAction() {
    this.next()
  }

  previousAction() {
    this.previous()
  }

  pauseAction() {
    this.autoPlay = false
    this.stopAutoPlay()
  }

  resumeAction() {
    this.autoPlay = true
    this.startAutoPlay()
  }
}