import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["spendingChart", "categoryChart", "balanceChart"]

  connect() {
    try {
      // Delay chart initialization to avoid CSS conflicts
      setTimeout(() => {
        this.initializeCharts()
      }, 200)
    } catch (error) {
      console.error('Error initializing dashboard charts:', error)
    }
  }

  disconnect() {
    if (this.charts) {
      this.charts.forEach(chart => {
        if (chart && typeof chart.destroy === 'function') {
          chart.destroy()
        }
      })
    }
  }

  get spendingData() {
    try {
      const input = document.getElementById('spending-data')
      if (!input) return []
      return JSON.parse(input.value || '[]')
    } catch (_) { return [] }
  }

  get categoryData() {
    try {
      const input = document.getElementById('category-data')
      if (!input) return []
      return JSON.parse(input.value || '[]')
    } catch (_) { return [] }
  }

  get balanceData() {
    try {
      const input = document.getElementById('balance-data')
      if (!input) return []
      return JSON.parse(input.value || '[]')
    } catch (_) { return [] }
  }

  initializeCharts() {
    this.charts = []

    // Create charts with isolated CSS context
    if (this.hasSpendingChartTarget && this.spendingData.length > 0) {
      this.createSpendingChart()
    }
    
    if (this.hasCategoryChartTarget && this.categoryData.length > 0) {
      this.createCategoryChart()
    }
    
    if (this.hasBalanceChartTarget && this.balanceData.length > 0) {
      this.createBalanceChart()
    }
  }

  // Helper to create isolated chart container
  createIsolatedChartContainer(canvas) {
    const container = canvas.parentElement
    const isolatedContainer = document.createElement('div')
    isolatedContainer.style.cssText = `
      position: relative;
      width: 100%;
      height: 300px;
      isolation: isolate;
    `
    
    // Replace canvas with isolated container
    container.replaceChild(isolatedContainer, canvas)
    isolatedContainer.appendChild(canvas)
    
    // Set explicit canvas dimensions
    canvas.width = 600
    canvas.height = 300
    canvas.style.width = '100%'
    canvas.style.height = '100%'
    
    return canvas
  }

  createSpendingChart() {
    if (!this.hasSpendingChartTarget) return

    try {
      const canvas = this.spendingChartTarget
      const isolatedCanvas = this.createIsolatedChartContainer(canvas)

      const chart = new Chart(isolatedCanvas, {
        type: 'line',
        data: {
          labels: this.spendingData.map(d => d.month || 'Unknown'),
          datasets: [{
            label: 'Monthly Spending',
            data: this.spendingData.map(d => d.amount || 0),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            borderWidth: 3,
            fill: true,
            tension: 0.4,
            pointBackgroundColor: '#3b82f6',
            pointBorderColor: '#fff',
            pointBorderWidth: 2,
            pointRadius: 6,
            pointHoverRadius: 8
          }]
        },
        options: {
          responsive: false,
          maintainAspectRatio: false,
          animation: {
            duration: 1000,
            easing: 'easeInOutQuart'
          },
          interaction: {
            intersect: false,
            mode: 'index'
          },
          plugins: {
            legend: { display: false },
            tooltip: {
              backgroundColor: 'rgba(0, 0, 0, 0.8)',
              titleColor: '#fff',
              bodyColor: '#fff',
              borderColor: 'rgba(59, 130, 246, 0.5)',
              borderWidth: 1,
              callbacks: {
                label: function(context) {
                  return 'Spending: $' + (context.parsed.y || 0).toLocaleString()
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
                callback: function(value) {
                  return '$' + (value || 0).toLocaleString()
                },
                color: '#6b7280',
                font: { size: 12 }
              }
            },
            x: {
              grid: { display: false },
              ticks: {
                color: '#6b7280',
                font: { size: 12 }
              }
            }
          }
        }
      })

      this.charts.push(chart)
    } catch (error) {
      console.error('Error creating spending chart:', error)
      this.showChartFallback('spendingChart', this.spendingData, 'Monthly Spending')
    }
  }

  createCategoryChart() {
    if (!this.hasCategoryChartTarget) return

    try {
      const canvas = this.categoryChartTarget
      const isolatedCanvas = this.createIsolatedChartContainer(canvas)

      const chart = new Chart(isolatedCanvas, {
        type: 'doughnut',
        data: {
          labels: this.categoryData.map(d => d[0] || 'Unknown'),
          datasets: [{
            data: this.categoryData.map(d => Math.abs(d[1] || 0)),
            backgroundColor: [
              '#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6',
              '#06b6d4', '#84cc16', '#f97316', '#ec4899', '#6366f1'
            ],
            borderWidth: 0,
            hoverBorderWidth: 2,
            hoverBorderColor: '#fff'
          }]
        },
        options: {
          responsive: false,
          maintainAspectRatio: false,
          animation: {
            duration: 1000,
            easing: 'easeInOutQuart'
          },
          plugins: {
            legend: {
              position: 'bottom',
              labels: {
                padding: 20,
                usePointStyle: true,
                font: { size: 12 }
              }
            },
            tooltip: {
              backgroundColor: 'rgba(0, 0, 0, 0.8)',
              titleColor: '#fff',
              bodyColor: '#fff',
              callbacks: {
                label: function(context) {
                  const total = context.dataset.data.reduce((a, b) => a + b, 0)
                  const percentage = total > 0 ? ((context.parsed / total) * 100).toFixed(1) : '0.0'
                  return context.label + ': $' + (context.parsed || 0).toLocaleString() + ' (' + percentage + '%)'
                }
              }
            }
          },
          cutout: '60%'
        }
      })

      this.charts.push(chart)
    } catch (error) {
      console.error('Error creating category chart:', error)
      this.showChartFallback('categoryChart', this.categoryData, 'Spending by Category')
    }
  }

  createBalanceChart() {
    if (!this.hasBalanceChartTarget) return

    try {
      const canvas = this.balanceChartTarget
      
      // Simple chart creation without complex DOM manipulation
      const chart = new Chart(canvas, {
        type: 'bar',
        data: {
          labels: this.balanceData.map(d => d.account?.bank_name || 'Unknown'),
          datasets: [{
            label: 'Account Balance',
            data: this.balanceData.map(d => d.balance || 0),
            backgroundColor: this.balanceData.map(d => d.balance >= 0 ? '#10b981' : '#ef4444'),
            borderColor: this.balanceData.map(d => d.balance >= 0 ? '#059669' : '#dc2626'),
            borderWidth: 1,
            borderRadius: 4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          plugins: {
            legend: { display: false },
            tooltip: { enabled: false }
          },
          scales: {
            y: {
              beginAtZero: true,
              grid: { display: false },
              ticks: { color: '#6b7280' }
            },
            x: {
              grid: { display: false },
              ticks: { color: '#6b7280' }
            }
          }
        }
      })

      this.charts.push(chart)
    } catch (error) {
      console.error('Error creating balance chart:', error)
      this.showChartFallback('balanceChart', this.balanceData, 'Account Balances')
    }
  }

  showChartFallback(chartId, data, title) {
    const canvas = document.querySelector(`[data-dashboard-charts-target="${chartId}"]`)
    if (!canvas) return
    
    const container = canvas.parentElement
    container.innerHTML = `
      <div class="chart-fallback p-4 text-center">
        <h4 class="font-semibold text-gray-700 mb-2">${title}</h4>
        <div class="text-sm text-gray-600">
          ${this.formatDataAsText(data, title)}
        </div>
      </div>
    `
  }

  formatDataAsText(data, title) {
    if (title === 'Monthly Spending') {
      return data.map(d => `${d.month}: $${d.amount?.toLocaleString() || 0}`).join('<br>')
    } else if (title === 'Spending by Category') {
      return data.map(d => `${d[0]}: $${Math.abs(d[1] || 0).toLocaleString()}`).join('<br>')
    } else if (title === 'Account Balances') {
      return data.map(d => `${d.account?.bank_name || 'Unknown'}: $${d.balance?.toLocaleString() || 0}`).join('<br>')
    }
    return 'Data available but chart could not be rendered'
  }
}
