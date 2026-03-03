import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = { url: String }

  toggle() {
    const completed = this.checkboxTarget.checked

    this.element.classList.toggle("completed", completed)

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ todo_list_item: { completed } })
    }).then(response => {
      if (!response.ok) {
        this.checkboxTarget.checked = !completed
        this.element.classList.toggle("completed", !completed)
      }
    }).catch(() => {
      this.checkboxTarget.checked = !completed
      this.element.classList.toggle("completed", !completed)
    })
  }
}
