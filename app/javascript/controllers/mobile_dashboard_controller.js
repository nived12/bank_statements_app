import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["tab", "content", "spendingChart", "categoryChart", "balanceChart"]
  static values = { 
    spendingData: Array, 
    categoryData: Array, 
    balanceData: Array,
    isMobile: Boolean 
  }

  connect() {
    this.initializeTabs()
    this.initializeCharts()
    this.setupMobileOptimizations()
  }

  initializeTabs() {
    // Set up tab switching
    this.tabTargets.forEach(tab => {
      tab.addEventListener('click', (e) => {
        e.preventDefault()
        this.switchTab(tab.dataset.tab)
      })
    })
  }

  switchTab(tabName) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === tabName) {
        tab.classList.add('mobile-tab-active')
      } else {
        tab.classList.remove('mobile-tab-active')
      }
    })

    // Update tab content
    this.contentTargets.forEach(content => {
      if (content.dataset.content === tabName) {
        content.classList.add('mobile-tab-content-active')
        content.classList.remove('mobile-tab-content')
      } else {
        content.classList.remove('mobile-tab-content-active')
        content.classList.add('mobile-tab-content')
      }
    })

    // Initialize charts when switching to relevant tabs
    if (tabName === 'overview') {
      this.initializeSpendingChart()
    } else if (tabName === 'categories') {
      this.initializeCategoryChart()
    }
  }

  initializeCharts() {
    // Initialize charts with a small delay to ensure DOM is ready
    setTimeout(() => {
      this.initializeSpendingChart()
      this.initializeCategoryChart()
      this.initializeBalanceChart()
    }, 100)
  }

  setupMobileOptimizations() {
    // Add mobile-specific optimizations
    if (this.isMobileValue) {
      this.setupTouchInteractions()
      this.setupResponsiveCharts()
    }
  }

  setupTouchInteractions() {
    // Add touch-friendly interactions for charts
    this.element.addEventListener('touchstart', this.handleTouchStart.bind(this))
    this.element.addEventListener('touchmove', this.handleTouchMove.bind(this))
    this.element.addEventListener('touchend', this.handleTouchEnd.bind(this))
  }

  setupResponsiveCharts() {
    // Handle window resize for mobile orientation changes
    window.addEventListener('resize', this.debounce(() => {
      this.resizeCharts()
    }, 250))
  }

  handleTouchStart(e) {
    // Handle touch interactions for better mobile UX
    this.touchStartX = e.touches[0].clientX
    this.touchStartY = e.touches[0].clientY
  }

  handleTouchMove(e) {
    // Prevent default scrolling on chart areas
    if (e.target.closest('.mobile-chart-container')) {
      e.preventDefault()
    }
  }

  handleTouchEnd(e) {
    // Handle touch end for potential chart interactions
    const touchEndX = e.changedTouches[0].clientX
    const touchEndY = e.changedTouches[0].clientY
    const deltaX = Math.abs(touchEndX - this.touchStartX)
    const deltaY = Math.abs(touchEndY - this.touchStartY)
    
    // If it's a tap (not a swipe), we could add chart interaction here
    if (deltaX < 10 && deltaY < 10) {
      // Handle tap on chart
    }
  }

  resizeCharts() {
    // Resize all charts when orientation changes
    if (this.spendingChart) {
      this.spendingChart.resize()
    }
    if (this.categoryChart) {
      this.categoryChart.resize()
    }
    if (this.balanceChart) {
      this.balanceChart.resize()
    }
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }

  initializeSpendingChart() {
    if (!this.hasSpendingChartTarget) return

    const spendingData = this.getSpendingData()
    if (spendingData.length === 0) return

    const ctx = this.spendingChartTarget.getContext('2d')
    
    // Destroy existing chart if it exists
    if (this.spendingChart) {
      this.spendingChart.destroy()
    }

    this.spendingChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: spendingData.map(d => d.month || 'Unknown'),
        datasets: [{
          label: 'Gastos Mensuales',
          data: spendingData.map(d => d.amount || 0),
          borderColor: '#3b82f6',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          borderWidth: this.isMobileValue ? 2 : 3,
          fill: true,
          tension: 0.4,
          pointBackgroundColor: '#3b82f6',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: this.isMobileValue ? 6 : 4,
          pointHoverRadius: this.isMobileValue ? 8 : 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: true,
            position: 'nearest',
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: '#3b82f6',
            borderWidth: 1,
            cornerRadius: 8,
            displayColors: false,
            titleFont: { size: 12 },
            bodyFont: { size: 11 },
            padding: 8
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { 
              color: 'rgba(0, 0, 0, 0.1)',
              drawBorder: false
            },
            ticks: {
              font: { size: this.isMobileValue ? 10 : 12 },
              callback: function(value) {
                return '$' + (value || 0).toLocaleString()
              }
            }
          },
          x: {
            grid: { display: false },
            ticks: { 
              maxRotation: this.isMobileValue ? 0 : 45,
              font: { size: this.isMobileValue ? 10 : 12 }
            }
          }
        }
      }
    })
  }

  initializeCategoryChart() {
    if (!this.hasCategoryChartTarget) return

    const categoryData = this.getCategoryData()
    if (categoryData.length === 0) return

    const ctx = this.categoryChartTarget.getContext('2d')
    
    // Destroy existing chart if it exists
    if (this.categoryChart) {
      this.categoryChart.destroy()
    }

    this.categoryChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: categoryData.map(d => d[0] || 'Unknown'),
        datasets: [{
          data: categoryData.map(d => Math.abs(d[1] || 0)),
          backgroundColor: [
            '#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6',
            '#06b6d4', '#84cc16', '#f97316', '#ec4899', '#6366f1'
          ],
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false
        },
        plugins: {
          legend: {
            position: this.isMobileValue ? 'bottom' : 'right',
            labels: {
              padding: this.isMobileValue ? 8 : 10,
              usePointStyle: true,
              font: { size: this.isMobileValue ? 10 : 11 },
              boxWidth: this.isMobileValue ? 12 : 14
            }
          },
          tooltip: {
            enabled: true,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: '#3b82f6',
            borderWidth: 1,
            cornerRadius: 8,
            displayColors: true,
            titleFont: { size: 12 },
            bodyFont: { size: 11 },
            padding: 8,
            callbacks: {
              label: function(context) {
                const total = context.dataset.data.reduce((a, b) => a + b, 0)
                const percentage = ((context.parsed / total) * 100).toFixed(1)
                return `${context.label}: $${context.parsed.toLocaleString()} (${percentage}%)`
              }
            }
          }
        },
        cutout: this.isMobileValue ? '50%' : '60%'
      }
    })
  }

  initializeBalanceChart() {
    if (!this.hasBalanceChartTarget) return

    const balanceData = this.getBalanceData()
    if (balanceData.length === 0) return

    const ctx = this.balanceChartTarget.getContext('2d')
    
    // Destroy existing chart if it exists
    if (this.balanceChart) {
      this.balanceChart.destroy()
    }

    this.balanceChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: balanceData.map(d => d.name || 'Unknown'),
        datasets: [{
          label: 'Balance por Cuenta',
          data: balanceData.map(d => d.balance || 0),
          backgroundColor: balanceData.map((d, index) => {
            const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6']
            return colors[index % colors.length]
          }),
          borderWidth: 0,
          borderRadius: this.isMobileValue ? 4 : 6,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: true,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: '#3b82f6',
            borderWidth: 1,
            cornerRadius: 8,
            displayColors: false,
            titleFont: { size: 12 },
            bodyFont: { size: 11 },
            padding: 8,
            callbacks: {
              label: function(context) {
                return `${context.label}: $${context.parsed.y.toLocaleString()}`
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { 
              color: 'rgba(0, 0, 0, 0.1)',
              drawBorder: false
            },
            ticks: {
              font: { size: this.isMobileValue ? 10 : 12 },
              callback: function(value) {
                return '$' + (value || 0).toLocaleString()
              }
            }
          },
          x: {
            grid: { display: false },
            ticks: { 
              font: { size: this.isMobileValue ? 10 : 12 },
              maxRotation: this.isMobileValue ? 0 : 45
            }
          }
        }
      }
    })
  }

  getSpendingData() {
    try {
      // Try to get data from Stimulus values first
      if (this.spendingDataValue && this.spendingDataValue.length > 0) {
        return this.spendingDataValue
      }
      
      // Fallback to hidden input
      const input = document.getElementById('mobile-spending-data')
      if (!input) return []
      return JSON.parse(input.value || '[]')
    } catch (_) { 
      return [] 
    }
  }

  getCategoryData() {
    try {
      // Try to get data from Stimulus values first
      if (this.categoryDataValue && this.categoryDataValue.length > 0) {
        return this.categoryDataValue
      }
      
      // Fallback to hidden input
      const input = document.getElementById('mobile-category-data')
      if (!input) return []
      return JSON.parse(input.value || '[]')
    } catch (_) { 
      return [] 
    }
  }

  getBalanceData() {
    try {
      // Try to get data from Stimulus values first
      if (this.balanceDataValue && this.balanceDataValue.length > 0) {
        return this.balanceDataValue
      }
      
      // Fallback to hidden input
      const input = document.getElementById('mobile-balance-data')
      if (!input) return []
      return JSON.parse(input.value || '[]')
    } catch (_) { 
      return [] 
    }
  }

  disconnect() {
    if (this.spendingChart) {
      this.spendingChart.destroy()
    }
    if (this.categoryChart) {
      this.categoryChart.destroy()
    }
    if (this.balanceChart) {
      this.balanceChart.destroy()
    }
  }
}
