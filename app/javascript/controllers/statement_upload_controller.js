import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="statement-upload"
export default class extends Controller {
  static targets = [
    "form",
    "submitButton",
    "fileInput",
    "uploadArea",
    "fileName",
    "selectedFileName",
    "uploadBtn",
    "uploadProgress",
    "aiToggle",
    "aiStatusText",
    "aiProcessingHelp",
    "toggleTrack",
    "toggleHandle",
    "cutoffDateInput",
    "bankAccountSelect"
  ]

  connect() {
    // Store original form data for change detection
    if (this.hasFormTarget) {
      this.originalFormData = new FormData(this.formTarget)
    }

    // Set initial cutoff_date to today
    if (this.hasCutoffDateInputTarget) {
      this.cutoffDateInputTarget.value = this.formatDateForInput(new Date())
    }

    // Check if there's a pre-selected bank account from query params
    if (this.hasBankAccountSelectTarget) {
      const urlParams = new URLSearchParams(window.location.search)
      const preselectedBankAccountId = urlParams.get('bank_account_id')
      if (preselectedBankAccountId) {
        this.bankAccountSelectTarget.value = preselectedBankAccountId
        this.updateCutoffDate(preselectedBankAccountId)
      }
    }

    // Initialize AI toggle state based on checkbox value
    this.initializeAiToggle()

    // Check initial changes state
    this.checkChanges()
  }

  // Initialize AI toggle UI based on checkbox state
  initializeAiToggle() {
    if (!this.hasAiToggleTarget || !this.hasAiStatusTextTarget || !this.hasAiProcessingHelpTarget ||
        !this.hasToggleTrackTarget || !this.hasToggleHandleTarget) return

    if (this.aiToggleTarget.checked) {
      // AI Enabled
      this.toggleTrackTarget.classList.remove('bg-slate-200')
      this.toggleTrackTarget.classList.add('bg-blue-600')
      this.toggleHandleTarget.style.transform = 'translateX(24px)'
      this.aiStatusTextTarget.textContent = this.aiStatusTextTarget.dataset.enabledText
      this.aiProcessingHelpTarget.textContent = this.aiProcessingHelpTarget.dataset.enabledText
    } else {
      // AI Disabled
      this.toggleTrackTarget.classList.remove('bg-blue-600')
      this.toggleTrackTarget.classList.add('bg-slate-200')
      this.toggleHandleTarget.style.transform = 'translateX(0px)'
      this.aiStatusTextTarget.textContent = this.aiStatusTextTarget.dataset.disabledText
      this.aiProcessingHelpTarget.textContent = this.aiProcessingHelpTarget.dataset.disabledText
    }
  }

  // Update file name display when file is selected
  updateFileName(event) {
    if (!this.hasFileInputTarget || !this.hasFileNameTarget || !this.hasSelectedFileNameTarget) return

    // Get files from event or input (event.target.files works even if extension clears input.files)
    const files = event?.target?.files || this.fileInputTarget.files

    if (files && files.length > 0) {
      const file = files[0]

      // Store file reference before extension can clear it
      this.selectedFile = file
      this.selectedFileName = file.name

      this.selectedFileNameTarget.textContent = file.name
      this.fileNameTarget.classList.remove('hidden')

      if (this.hasUploadAreaTarget) {
        this.uploadAreaTarget.classList.add('border-blue-400', 'bg-blue-50')
      }
    } else {
      this.fileNameTarget.classList.add('hidden')

      if (this.hasUploadAreaTarget) {
        this.uploadAreaTarget.classList.remove('border-blue-400', 'bg-blue-50')
      }
    }

    this.checkChanges()
  }

  // Handle drag over
  handleDragOver(event) {
    event.preventDefault()
    if (this.hasUploadAreaTarget) {
      this.uploadAreaTarget.classList.add('border-blue-400', 'bg-blue-50')
    }
  }

  // Handle drag leave
  handleDragLeave(event) {
    event.preventDefault()
    if (this.hasUploadAreaTarget && !this.uploadAreaTarget.contains(event.relatedTarget)) {
      this.uploadAreaTarget.classList.remove('border-blue-400', 'bg-blue-50')
    }
  }

  // Handle file drop
  handleDrop(event) {
    event.preventDefault()

    if (this.hasUploadAreaTarget) {
      this.uploadAreaTarget.classList.remove('border-blue-400', 'bg-blue-50')
    }

    const files = event.dataTransfer.files
    if (files.length > 0 && files[0].type === 'application/pdf' && this.hasFileInputTarget) {
      this.fileInputTarget.files = files
      this.updateFileName()
    }
  }

  // Toggle AI processing
  toggleAi() {
    if (!this.hasAiToggleTarget || !this.hasAiStatusTextTarget || !this.hasAiProcessingHelpTarget ||
        !this.hasToggleTrackTarget || !this.hasToggleHandleTarget) return

    this.aiToggleTarget.checked = !this.aiToggleTarget.checked

    if (this.aiToggleTarget.checked) {
      // AI Enabled
      this.toggleTrackTarget.classList.remove('bg-slate-200')
      this.toggleTrackTarget.classList.add('bg-blue-600')
      this.toggleHandleTarget.style.transform = 'translateX(24px)'
      this.aiStatusTextTarget.textContent = this.aiStatusTextTarget.dataset.enabledText
      this.aiProcessingHelpTarget.textContent = this.aiProcessingHelpTarget.dataset.enabledText
    } else {
      // AI Disabled
      this.toggleTrackTarget.classList.remove('bg-blue-600')
      this.toggleTrackTarget.classList.add('bg-slate-200')
      this.toggleHandleTarget.style.transform = 'translateX(0px)'
      this.aiStatusTextTarget.textContent = this.aiStatusTextTarget.dataset.disabledText
      this.aiProcessingHelpTarget.textContent = this.aiProcessingHelpTarget.dataset.disabledText
    }

    this.checkChanges()
  }

  // Handle bank account selection change
  handleBankAccountChange() {
    if (!this.hasBankAccountSelectTarget) return

    const selectedBankAccountId = this.bankAccountSelectTarget.value
    if (selectedBankAccountId) {
      this.updateCutoffDate(selectedBankAccountId)
    }

    this.checkChanges()
  }

  // Update cutoff date based on selected bank account
  async updateCutoffDate(bankAccountId) {
    if (!this.hasCutoffDateInputTarget || !bankAccountId) return

    try {
      const url = `/bank_accounts/${bankAccountId}/statement_files.json?sort[cutoff_date]=desc`

      const response = await fetch(url)
      if (!response.ok) {
        throw new Error('Failed to fetch statement files')
      }

      const statementFiles = await response.json()

      if (statementFiles && statementFiles.length > 0 && statementFiles[0].cutoff_date) {
        const lastCutoffDate = new Date(statementFiles[0].cutoff_date)
        const nextCutoffDate = this.addMonths(lastCutoffDate, 1)
        this.cutoffDateInputTarget.value = this.formatDateForInput(nextCutoffDate)
      } else {
        this.cutoffDateInputTarget.value = this.formatDateForInput(new Date())
      }
    } catch (error) {
      console.error('Error fetching latest cutoff date:', error)
      this.cutoffDateInputTarget.value = this.formatDateForInput(new Date())
    }
  }

  // Show upload spinner on form submit
  showUploadSpinner(event) {
    if (!this.hasFileInputTarget) return false

    // Validate that a file is selected
    if (!this.fileInputTarget.files || this.fileInputTarget.files.length === 0) {
      event.preventDefault()
      alert('Por favor selecciona un archivo PDF para subir.')
      return false
    }

    if (this.hasUploadBtnTarget && this.hasUploadProgressTarget) {
      this.uploadBtnTarget.style.display = 'none'
      this.uploadProgressTarget.classList.remove('hidden')

      // Disable all form fields
      if (this.hasFormTarget) {
        const inputs = this.formTarget.querySelectorAll('input, select, button')
        inputs.forEach(input => {
          input.disabled = true
        })
      }
    }

    return true
  }

  // Check if form has changes (for submit button state)
  checkChanges() {
    if (!this.hasFormTarget) return

    // For upload forms, enable button if bank account is selected and file is chosen
    const hasBankAccount = this.hasBankAccountSelectTarget && this.bankAccountSelectTarget.value
    // Check both the file input AND our stored selectedFile (in case extension cleared the input)
    const hasFile = (this.hasFileInputTarget && this.fileInputTarget.files && this.fileInputTarget.files.length > 0) || this.selectedFileName
    const hasChanges = hasBankAccount && hasFile

    // Update mobile upload button (if present)
    if (this.hasUploadBtnTarget) {
      if (hasChanges) {
        this.uploadBtnTarget.disabled = false
        this.uploadBtnTarget.classList.remove("bg-slate-300", "cursor-not-allowed")
        this.uploadBtnTarget.classList.add("bg-blue-600", "hover:bg-blue-700", "cursor-pointer")
      } else {
        this.uploadBtnTarget.disabled = true
        this.uploadBtnTarget.classList.add("bg-slate-300", "cursor-not-allowed")
        this.uploadBtnTarget.classList.remove("bg-blue-600", "hover:bg-blue-700", "cursor-pointer")
      }
    }

    // Update checkmark submit button (if present - used in some layouts)
    if (this.hasSubmitButtonTarget) {
      if (hasChanges) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.classList.remove("text-slate-400", "cursor-not-allowed")
        this.submitButtonTarget.classList.add("text-green-600", "hover:bg-green-50")
      } else {
        this.submitButtonTarget.disabled = true
        this.submitButtonTarget.classList.add("text-slate-400", "cursor-not-allowed")
        this.submitButtonTarget.classList.remove("text-green-600", "hover:bg-green-50")
      }
    }
  }

  // Submit form via header button
  submit(event) {
    event.preventDefault()

    // Check if either button is enabled
    const uploadBtnEnabled = this.hasUploadBtnTarget && !this.uploadBtnTarget.disabled
    const submitBtnEnabled = this.hasSubmitButtonTarget && !this.submitButtonTarget.disabled

    if ((uploadBtnEnabled || submitBtnEnabled) && this.hasFormTarget) {
      // Just submit - the turbo:submit-start event will handle showUploadSpinner
      this.formTarget.requestSubmit()
    }
  }

  // Helper: Format date as YYYY-MM-DD
  formatDateForInput(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  // Helper: Add months to a date
  addMonths(date, months) {
    const result = new Date(date)
    result.setMonth(result.getMonth() + months)
    return result
  }
}
