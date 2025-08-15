import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["spendingChart", "categoryChart", "balanceChart"]
  static values = { 
    spendingData: Array,
    categoryData: Array,
    balanceData: Array
  }

  connect() {
    this.initializeCharts()
  }

  initializeCharts() {
    if (this.hasSpendingChartTarget) {
      this.createSpendingChart()
    }
    
    if (this.hasCategoryChartTarget) {
      this.createCategoryChart()
    }
    
    if (this.hasBalanceChartTarget) {
      this.createBalanceChart()
    }
  }

  createSpendingChart() {
    const ctx = this.spendingChartTarget.getContext('2d')
    
    new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.spendingDataValue.map(d => d.month),
        datasets: [{
          label: 'Monthly Spending',
          data: this.spendingDataValue.map(d => d.amount),
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
                return 'Spending: $' + context.parsed.y.toLocaleString()
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
                return '$' + value.toLocaleString()
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
  }

  createCategoryChart() {
    const ctx = this.categoryChartTarget.getContext('2d')
    
    new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: this.categoryDataValue.map(d => d[0]),
        datasets: [{
          data: this.categoryDataValue.map(d => Math.abs(d[1])),
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
                const percentage = ((context.parsed / total) * 100).toFixed(1)
                return context.label + ': $' + context.parsed.toLocaleString() + ' (' + percentage + '%)'
              }
            }
          }
        },
        cutout: '60%'
      }
    })
  }

  createBalanceChart() {
    const ctx = this.balanceChartTarget.getContext('2d')
    
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: this.balanceDataValue.map(d => d.account.bank_name),
        datasets: [{
          label: 'Account Balance',
          data: this.balanceDataValue.map(d => d.balance),
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
                return 'Balance: $' + context.parsed.y.toLocaleString()
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
                return '$' + value.toLocaleString()
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
  }
}
