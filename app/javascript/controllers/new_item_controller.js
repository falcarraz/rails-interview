import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  reset(event) {
    if (event.detail.success) {
      this.formTarget.reset()
      this.inputTarget.focus()
    }
  }
}
