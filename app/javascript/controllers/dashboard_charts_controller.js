import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["spendingChart", "categoryChart", "balanceChart"]

  connect() {
    try {
      this.initializeCharts()
    } catch (error) {
      console.error('Error initializing dashboard charts:', error)
    }
  }

  disconnect() {
    // Clean up charts to prevent memory leaks
    if (this.charts) {
      this.charts.forEach(chart => {
        if (chart && typeof chart.destroy === 'function') {
          chart.destroy()
        }
      })
    }
  }

  // Read data from hidden input fields
  get spendingData() {
    try {
      const input = document.getElementById('spending-data')
      if (!input) {
        console.warn('Spending data input field not found')
        return []
      }
      const data = JSON.parse(input.value || '[]')
      console.log('Spending data loaded:', data)
      return data
    } catch (error) {
      console.error('Error parsing spending data:', error)
      console.error('Raw value:', document.getElementById('spending-data')?.value)
      return []
    }
  }

  get categoryData() {
    try {
      const input = document.getElementById('category-data')
      if (!input) {
        console.warn('Category data input field not found')
        return []
      }
      const data = JSON.parse(input.value || '[]')
      console.log('Category data loaded:', data)
      return data
    } catch (error) {
      console.error('Error parsing category data:', error)
      console.error('Raw value:', document.getElementById('category-data')?.value)
      return []
    }
  }

  get balanceData() {
    try {
      const input = document.getElementById('balance-data')
      if (!input) {
        console.warn('Balance data input field not found')
        return []
      }
      const data = JSON.parse(input.value || '[]')
      console.log('Balance data loaded:', data)
      return data
    } catch (error) {
      console.error('Error parsing balance data:', error)
      console.error('Raw value:', document.getElementById('balance-data')?.value)
      return []
    }
  }

  initializeCharts() {
    this.charts = []
    
    if (this.hasSpendingChartTarget && this.spendingData.length > 0) {
      try {
        this.createSpendingChart()
      } catch (error) {
        console.error('Error creating spending chart:', error)
      }
    }
    
    if (this.hasCategoryChartTarget && this.categoryData.length > 0) {
      try {
        this.createCategoryChart()
      } catch (error) {
        console.error('Error creating category chart:', error)
      }
    }
    
    if (this.hasBalanceChartTarget && this.balanceData.length > 0) {
      try {
        this.createBalanceChart()
      } catch (error) {
        console.error('Error creating balance chart:', error)
      }
    }
  }

  createSpendingChart() {
    if (!this.hasSpendingChartTarget) return
    
    const ctx = this.spendingChartTarget.getContext('2d')
    if (!ctx) return
    
    const chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.spendingData.map(d => d.month || 'Unknown'),
        datasets: [{
          label: 'Monthly Spending',
          data: this.spendingData.map(d => d.amount || 0),
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          borderWidth: 3,
          fill: true,
          tension: 0.4,
          pointBackgroundColor: 'rgb(59, 130, 246)',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 6,
          pointHoverRadius: 8
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
          legend: {
            display: false
          },
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
              font: {
                size: 12
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#6b7280',
              font: {
                size: 12
              }
            }
          }
        },
        elements: {
          point: {
            hoverRadius: 8
          }
        }
      }
    })
    
    this.charts.push(chart)
  }

  createCategoryChart() {
    if (!this.hasCategoryChartTarget) return
    
    const ctx = this.categoryChartTarget.getContext('2d')
    if (!ctx) return
    
    const chart = new Chart(ctx, {
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
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              padding: 20,
              usePointStyle: true,
              font: {
                size: 12
              }
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
  }

  createBalanceChart() {
    if (!this.hasBalanceChartTarget) return
    
    const ctx = this.balanceChartTarget.getContext('2d')
    if (!ctx) return
    
    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: this.balanceData.map(d => d.account?.bank_name || 'Unknown'),
        datasets: [{
          label: 'Account Balance',
          data: this.balanceData.map(d => d.balance || 0),
          backgroundColor: 'rgba(59, 130, 246, 0.8)',
          borderColor: 'rgb(59, 130, 246)',
          borderWidth: 1,
          borderRadius: 8,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: '#fff',
            bodyColor: '#fff',
            callbacks: {
              label: function(context) {
                return 'Balance: $' + (context.parsed.y || 0).toLocaleString()
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
              font: {
                size: 12
              }
            }
          },
          x: {
            grid: {
              display: false
            },
            ticks: {
              color: '#6b7280',
              font: {
                size: 12
              }
            }
          }
        }
      }
    })
    
    this.charts.push(chart)
  }
}
