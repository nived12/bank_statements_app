// Local Time Utilities
// This file handles all UTC to local time conversions throughout the application

class LocalTimeManager {
  constructor() {
    this.init();
  }

  init() {
    // Initialize all time conversions when DOM is loaded
    document.addEventListener('DOMContentLoaded', () => {
      this.convertAllUtcTimes();
      this.setupDateInputs();
    });
  }

  // Convert all UTC times to local time
  convertAllUtcTimes() {
    const utcTimeElements = document.querySelectorAll('[data-utc-time]');
    utcTimeElements.forEach(element => {
      this.convertUtcToLocal(element);
    });
  }

  // Convert a single UTC time element to local time
  convertUtcToLocal(element) {
    const utcTime = element.getAttribute('data-utc-time');
    if (!utcTime) return;

    const localDate = new Date(utcTime);
    
    // Determine format based on element class or data attribute
    const format = element.getAttribute('data-format') || 'default';
    const options = this.getFormatOptions(format);
    
    element.textContent = localDate.toLocaleDateString('es-MX', options);
  }

  // Get format options based on the format type
  getFormatOptions(format) {
    const formatMap = {
      'full': {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      },
      'short': {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      },
      'month-year': {
        year: 'numeric',
        month: 'long'
      },
      'default': {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      }
    };

    return formatMap[format] || formatMap['default'];
  }

  // Setup date inputs with local timezone
  setupDateInputs() {
    // Handle date inputs that need local date setting
    const dateInputs = document.querySelectorAll('[data-set-local-date]');
    dateInputs.forEach(input => {
      this.setLocalDateInput(input);
    });

    // Handle current month options
    const currentMonthOptions = document.querySelectorAll('[data-current-month]');
    currentMonthOptions.forEach(option => {
      this.setCurrentMonthOption(option);
    });
  }

  // Set a date input to today's local date
  setLocalDateInput(input) {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    const todayString = `${year}-${month}-${day}`;
    
    input.value = todayString;
    input.max = todayString;
  }

  // Set current month option
  setCurrentMonthOption(option) {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const monthYear = `${year}-${month}`;
    
    option.value = monthYear;
    option.textContent = now.toLocaleDateString('es-MX', { 
      year: 'numeric', 
      month: 'long' 
    });
  }

  // Public method to convert UTC time to local time (for dynamic content)
  convertUtcTime(utcTimeString, format = 'default') {
    const localDate = new Date(utcTimeString);
    const options = this.getFormatOptions(format);
    return localDate.toLocaleDateString('es-MX', options);
  }

  // Public method to get today's local date string
  getTodayLocalDateString() {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}

// Initialize the LocalTimeManager
const localTimeManager = new LocalTimeManager();

// Make it globally available
window.localTimeManager = localTimeManager;
