import { Controller } from "@hotwired/stimulus"

// Auto-dismisses success/notice flash messages after a delay; alerts stay until closed
export default class extends Controller {
  static values = { autoDismiss: Boolean }

  connect() {
    if (this.autoDismissValue) {
      this.timer = setTimeout(() => this.dismiss(), 5000)
    }
  }

  dismiss() {
    clearTimeout(this.timer)

    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.remove()
      return
    }

    const animation = this.element.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 200 })
    animation.onfinish = () => this.element.remove()
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
