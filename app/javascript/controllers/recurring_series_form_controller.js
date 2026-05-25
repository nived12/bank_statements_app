import BaseFormController from "./base_form_controller"

export default class extends BaseFormController {
  static targets = ["form", "submitButton"]

  connect() {
    super.connect()
  }

  getResourcePath() {
    return "/recurring_series"
  }
}
