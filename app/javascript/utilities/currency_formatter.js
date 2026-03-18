// Shared currency formatting utilities
// Used across multiple form controllers for consistent currency handling

export class CurrencyFormatter {
  // Add comma separators to numbers (e.g., 1234.56 -> 1,234.56, -1234.56 -> -1,234.56)
  static formatWithCommas(value) {
    const str = value.toString()
    const isNegative = str.startsWith("-")
    const parts = (isNegative ? str.slice(1) : str).split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return (isNegative ? "-" : "") + parts.join(".")
  }

  // Remove all commas from a string (e.g., 1,234.56 -> 1234.56)
  static stripCommas(value) {
    return value.replace(/,/g, "")
  }

  // Format a number as currency with 2 decimal places and commas
  // Returns empty string if value is invalid
  static formatCurrency(value) {
    // Only format if there's a value
    if (!value || value === "") {
      return ""
    }

    // Remove commas for parsing
    const cleanValue = this.stripCommas(value)

    // Parse the value as a float
    const numValue = parseFloat(cleanValue)

    // Check if it's a valid number
    if (isNaN(numValue)) {
      return ""
    }

    // Format to 2 decimal places with comma separators
    return this.formatWithCommas(numValue.toFixed(2))
  }
}
