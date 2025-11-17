import { Controller } from "@hotwired/stimulus"

// Transaction Index Controller - Handles transaction index functionality
export default class extends Controller {
  connect() {
  }

  deleteTransaction(event) {
    const transactionId = event.params.transactionId;
    if (confirm('<%= t("transactions.confirm_delete") %>')) {
      // Create a form to submit the DELETE request
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = `<%= root_path %>transactions/${transactionId}`;

      // Add CSRF token
      const csrfToken = document.createElement('input');
      csrfToken.type = 'hidden';
      csrfToken.name = 'authenticity_token';
      csrfToken.value = '<%= form_authenticity_token %>';
      form.appendChild(csrfToken);

      // Add method override for DELETE
      const methodInput = document.createElement('input');
      methodInput.type = 'hidden';
      methodInput.name = '_method';
      methodInput.value = 'delete';
      form.appendChild(methodInput);

      // Submit the form
      document.body.appendChild(form);
      form.submit();
    }
  }

  clearFilter(filterName) {
    const element = document.getElementById(filterName);
    if (element) {
      element.value = '';
      window.applyFilters();
    }
  }

  clearDateFilter() {
    const fromDateElement = document.getElementById('from_date');
    const toDateElement = document.getElementById('to_date');
    const dateRangeElement = document.getElementById('date_range');

    if (fromDateElement) fromDateElement.value = '';
    if (toDateElement) toDateElement.value = '';
    if (dateRangeElement) dateRangeElement.value = '';
    window.applyFilters();
  }

  clearAllFilters() {
    // Clear all filter inputs - safely handle elements that might not exist on mobile
    const bankAccountElement = document.getElementById('bank_account_id');
    const statementFileElement = document.getElementById('statement_file_id');
    const transactionTypeElement = document.getElementById('transaction_type');
    const fromDateElement = document.getElementById('from_date');
    const toDateElement = document.getElementById('to_date');
    const dateRangeElement = document.getElementById('date_range');

    if (bankAccountElement) bankAccountElement.value = '';
    if (statementFileElement) statementFileElement.value = '';
    if (transactionTypeElement) transactionTypeElement.value = '';
    if (fromDateElement) fromDateElement.value = '';
    if (toDateElement) toDateElement.value = '';
    if (dateRangeElement) dateRangeElement.value = '';

    // Clear both search inputs
    const desktopSearch = document.getElementById('search');
    const mobileSearch = document.getElementById('mobile-search');
    if (desktopSearch) desktopSearch.value = '';
    if (mobileSearch) mobileSearch.value = '';

    // Navigate to clean transactions page
    window.location.href = '/transactions';
  }

  disconnect() {

  }
}
