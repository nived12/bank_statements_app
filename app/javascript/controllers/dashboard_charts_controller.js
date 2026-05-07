import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["spendingChart", "balanceChart"]

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

  getTranslation(key) {
    const translationsElement = document.getElementById('translations')
    if (translationsElement) {
      const translations = JSON.parse(translationsElement.value)
      return translations[key]
    }
    return null
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
      try {
        this.createSpendingChart()
      } catch (error) {
        console.error('Error creating spending chart:', error)
        this.showChartFallback('spendingChart', this.spendingData, this.getTranslation('monthly_spending') || 'Monthly Spending')
      }
    }

    if (this.hasBalanceChartTarget && this.balanceData.length > 0) {
      try {
        this.createBalanceChart()
      } catch (error) {
        console.error('Error creating balance chart:', error)
        this.showChartFallback('balanceChart', this.balanceData, this.getTranslation('account_balances') || 'Account Balances')
      }
    } else if (this.hasBalanceChartTarget) {
      this.showChartFallback('balanceChart', [], this.getTranslation('account_balances') || 'Account Balances')
    }
  }

  // Helper to create isolated chart container
  createIsolatedChartContainer(canvas, height = 220) {
    const container = canvas.parentElement
    container.style.height = height + 'px'

    const isolatedContainer = document.createElement('div')
    isolatedContainer.style.cssText = `
      position: relative;
      width: 100%;
      height: ${height}px;
      isolation: isolate;
      overflow: hidden;
    `

    // Replace canvas with isolated container
    container.replaceChild(isolatedContainer, canvas)
    isolatedContainer.appendChild(canvas)

    // Set explicit canvas dimensions
    canvas.width = 600
    canvas.height = height
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
          labels: this.spendingData.map(d => d.month || this.getTranslation('unknown') || 'Unknown'),
          datasets: [{
            label: this.getTranslation('spending_trends') || 'Monthly Spending',
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
                label: (context) => {
                  const spendingLabel = this.getTranslation('spending') || 'Spending'
                  return spendingLabel + ': $' + (context.parsed.y || 0).toLocaleString()
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
      this.showChartFallback('spendingChart', this.spendingData, this.getTranslation('monthly_spending') || 'Monthly Spending')
    }
  }

  createBalanceChart() {
    if (!this.hasBalanceChartTarget) return

    try {
      const canvas = this.balanceChartTarget
      const container = canvas.parentElement
      const height = Math.max(container.clientHeight || 0, 220)
      const isolatedCanvas = this.createIsolatedChartContainer(canvas, height)

      const colors = ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#10b981', '#f97316', '#ec4899', '#6366f1']

      const chart = new Chart(isolatedCanvas, {
        type: 'bar',
        data: {
          labels: this.balanceData.map(d => d.account || this.getTranslation('unknown') || 'Unknown'),
          datasets: [{
            label: this.getTranslation('account_balances') || 'Account Balance',
            data: this.balanceData.map(d => d.balance || 0),
            backgroundColor: this.balanceData.map((d, i) => d.balance >= 0 ? colors[i % colors.length] : '#ef4444'),
            borderColor: this.balanceData.map((d, i) => d.balance >= 0 ? colors[i % colors.length] : '#dc2626'),
            borderWidth: 1,
            borderRadius: 4
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
            legend: { display: false },
            tooltip: {
              backgroundColor: 'rgba(0, 0, 0, 0.8)',
              titleColor: '#fff',
              bodyColor: '#fff',
              callbacks: {
                label: (context) => {
                  const balanceLabel = this.getTranslation('account_balances') || 'Balance'
                  return balanceLabel + ': $' + (context.parsed.y || 0).toLocaleString()
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
      console.error('Error creating balance chart:', error)
      this.showChartFallback('balanceChart', this.balanceData, this.getTranslation('account_balances') || 'Account Balances')
    }
  }

  showChartFallback(chartId, data, title) {
    const canvas = document.querySelector(`[data-dashboard-charts-target="${chartId}"]`)
    if (!canvas) return

    const container = canvas.parentElement
    container.innerHTML = ""

    const wrapper = document.createElement("div")
    wrapper.className = "chart-fallback p-4 text-center"

    const heading = document.createElement("h4")
    heading.className = "font-semibold text-gray-700 mb-2"
    heading.textContent = title

    const body = document.createElement("div")
    body.className = "text-sm text-gray-600"
    this.formatDataAsLines(data, chartId).forEach((line, i) => {
      if (i > 0) body.appendChild(document.createElement("br"))
      body.appendChild(document.createTextNode(line))
    })

    wrapper.appendChild(heading)
    wrapper.appendChild(body)
    container.appendChild(wrapper)
  }

  formatDataAsLines(data, chartId) {
    if (chartId === 'spendingChart') {
      return data.map(d => `${d.month}: $${d.amount?.toLocaleString() || 0}`)
    } else if (chartId === 'balanceChart') {
      if (data.length === 0) {
        return [this.getTranslation('no_bank_accounts') || 'No bank accounts found. Add bank accounts to see balance information.']
      }
      return data.map(d => `${d.account?.bank_name || this.getTranslation('unknown') || 'Unknown'}: $${d.balance?.toLocaleString() || 0}`)
    }
    return [this.getTranslation('chart_render_error') || 'Data available but chart could not be rendered']
  }
}
