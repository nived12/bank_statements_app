import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lazy", "image", "chart"]
  static values = { 
    enableLazyLoading: Boolean,
    enableImageOptimization: Boolean,
    enableChartOptimization: Boolean,
    enablePreloading: Boolean
  }

  connect() {
    this.setupPerformanceOptimizations()
    this.setupLazyLoading()
    this.setupImageOptimization()
    this.setupChartOptimization()
    this.setupPreloading()
  }

  setupPerformanceOptimizations() {
    // Enable passive event listeners for better scroll performance
    this.setupPassiveListeners()
    
    // Optimize for mobile viewport
    this.optimizeViewport()
    
    // Setup intersection observer for performance monitoring
    this.setupIntersectionObserver()
  }

  setupPassiveListeners() {
    // Add passive listeners for scroll events
    const scrollElements = this.element.querySelectorAll('[data-scroll]')
    scrollElements.forEach(element => {
      element.addEventListener('scroll', this.handleScroll.bind(this), { passive: true })
    })
  }

  optimizeViewport() {
    // Add mobile-specific viewport optimizations
    const viewport = document.querySelector('meta[name="viewport"]')
    if (viewport) {
      viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no')
    }
  }

  setupIntersectionObserver() {
    if ('IntersectionObserver' in window) {
      this.observer = new IntersectionObserver(
        this.handleIntersection.bind(this),
        {
          rootMargin: '50px 0px',
          threshold: 0.1
        }
      )
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        this.loadLazyContent(entry.target)
        this.observer.unobserve(entry.target)
      }
    })
  }

  setupLazyLoading() {
    if (!this.enableLazyLoadingValue) return

    this.lazyTargets.forEach(element => {
      if (this.observer) {
        this.observer.observe(element)
      } else {
        // Fallback for browsers without IntersectionObserver
        this.loadLazyContent(element)
      }
    })
  }

  loadLazyContent(element) {
    // Load lazy content based on data attributes
    const lazyType = element.dataset.lazyType
    
    switch (lazyType) {
      case 'image':
        this.loadLazyImage(element)
        break
      case 'chart':
        this.loadLazyChart(element)
        break
      case 'content':
        this.loadLazyContent(element)
        break
      default:
        this.loadGenericLazyContent(element)
    }
  }

  loadLazyImage(element) {
    const src = element.dataset.src
    if (src) {
      element.src = src
      element.classList.remove('lazy')
      element.classList.add('loaded')
    }
  }

  loadLazyChart(element) {
    // Trigger chart initialization
    const event = new CustomEvent('lazy:chart:load', {
      detail: { element: element },
      bubbles: true
    })
    element.dispatchEvent(event)
  }

  loadGenericLazyContent(element) {
    // Load generic lazy content
    const content = element.dataset.content
    if (content) {
      element.innerHTML = content
      element.classList.remove('lazy')
      element.classList.add('loaded')
    }
  }

  setupImageOptimization() {
    if (!this.enableImageOptimizationValue) return

    this.imageTargets.forEach(image => {
      this.optimizeImage(image)
    })
  }

  optimizeImage(image) {
    // Add loading="lazy" for native lazy loading
    if (!image.hasAttribute('loading')) {
      image.setAttribute('loading', 'lazy')
    }

    // Add decoding="async" for better performance
    if (!image.hasAttribute('decoding')) {
      image.setAttribute('decoding', 'async')
    }

    // Optimize image based on device pixel ratio
    this.optimizeImageForDevice(image)
  }

  optimizeImageForDevice(image) {
    const devicePixelRatio = window.devicePixelRatio || 1
    const isRetina = devicePixelRatio > 1
    
    if (isRetina && image.dataset.src2x) {
      image.src = image.dataset.src2x
    } else if (image.dataset.src) {
      image.src = image.dataset.src
    }
  }

  setupChartOptimization() {
    if (!this.enableChartOptimizationValue) return

    this.chartTargets.forEach(chart => {
      this.optimizeChart(chart)
    })
  }

  optimizeChart(chart) {
    // Add mobile-specific chart optimizations
    chart.addEventListener('chart:optimize', this.handleChartOptimize.bind(this))
  }

  handleChartOptimize(event) {
    const chart = event.detail.chart
    
    // Optimize chart for mobile
    if (chart.options) {
      chart.options.responsive = true
      chart.options.maintainAspectRatio = false
      
      // Reduce animation for better performance
      if (chart.options.animation) {
        chart.options.animation.duration = 300
      }
      
      // Optimize plugins for mobile
      if (chart.options.plugins) {
        chart.options.plugins.legend = {
          ...chart.options.plugins.legend,
          labels: {
            ...chart.options.plugins.legend.labels,
            font: { size: 10 }
          }
        }
      }
    }
  }

  setupPreloading() {
    if (!this.enablePreloadingValue) return

    // Preload critical resources
    this.preloadCriticalResources()
    
    // Preload next page on mobile
    this.setupNextPagePreloading()
  }

  preloadCriticalResources() {
    // Preload critical CSS
    const criticalCSS = document.querySelector('link[rel="preload"][as="style"]')
    if (criticalCSS) {
      criticalCSS.rel = 'stylesheet'
    }

    // Preload critical fonts
    const criticalFonts = document.querySelectorAll('link[rel="preload"][as="font"]')
    criticalFonts.forEach(font => {
      font.rel = 'stylesheet'
    })
  }

  setupNextPagePreloading() {
    // Preload next page links on mobile
    const nextPageLinks = this.element.querySelectorAll('a[data-preload="true"]')
    nextPageLinks.forEach(link => {
      link.addEventListener('mouseenter', this.preloadPage.bind(this), { once: true })
      link.addEventListener('touchstart', this.preloadPage.bind(this), { once: true })
    })
  }

  preloadPage(event) {
    const link = event.target.closest('a')
    if (link && link.href) {
      // Create a prefetch link
      const prefetchLink = document.createElement('link')
      prefetchLink.rel = 'prefetch'
      prefetchLink.href = link.href
      document.head.appendChild(prefetchLink)
    }
  }

  handleScroll(event) {
    // Throttle scroll events for better performance
    if (this.scrollTimeout) {
      clearTimeout(this.scrollTimeout)
    }
    
    this.scrollTimeout = setTimeout(() => {
      this.handleScrollThrottled(event)
    }, 16) // ~60fps
  }

  handleScrollThrottled(event) {
    // Handle scroll-based optimizations
    this.updateScrollPosition()
    this.handleInfiniteScroll()
  }

  updateScrollPosition() {
    // Update scroll position for mobile optimizations
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop
    this.element.dataset.scrollTop = scrollTop
  }

  handleInfiniteScroll() {
    // Handle infinite scroll for mobile lists
    const infiniteScrollElement = this.element.querySelector('[data-infinite-scroll]')
    if (infiniteScrollElement) {
      const rect = infiniteScrollElement.getBoundingClientRect()
      const isVisible = rect.top < window.innerHeight && rect.bottom > 0
      
      if (isVisible && !infiniteScrollElement.dataset.loading) {
        this.loadMoreContent(infiniteScrollElement)
      }
    }
  }

  loadMoreContent(element) {
    element.dataset.loading = 'true'
    
    const nextPageUrl = element.dataset.nextPageUrl
    if (nextPageUrl) {
      fetch(nextPageUrl)
        .then(response => response.text())
        .then(html => {
          this.appendContent(element, html)
          element.dataset.loading = 'false'
        })
        .catch(error => {
          console.error('Error loading more content:', error)
          element.dataset.loading = 'false'
        })
    }
  }

  appendContent(element, html) {
    const tempDiv = document.createElement('div')
    tempDiv.innerHTML = html
    
    const newContent = tempDiv.querySelector('[data-infinite-scroll-content]')
    if (newContent) {
      element.appendChild(newContent)
    }
  }

  // Performance monitoring
  measurePerformance(name, fn) {
    const start = performance.now()
    const result = fn()
    const end = performance.now()
    
    // Performance monitoring can be enabled in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`${name} took ${end - start} milliseconds`)
    }
    return result
  }

  // Cleanup
  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    
    if (this.scrollTimeout) {
      clearTimeout(this.scrollTimeout)
    }
  }
}
