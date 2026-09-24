import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "chooseYou.name"

// Prefills and remembers the participant/owner name, and warns about duplicate names
export default class extends Controller {
  static targets = ["input", "warning"]
  static values = { taken: Array }

  connect() {
    if (this.hasInputTarget && !this.inputTarget.value) {
      const remembered = this.readStoredName()
      if (remembered) this.inputTarget.value = remembered
    }

    this.check()
  }

  check() {
    if (!this.hasInputTarget || !this.hasWarningTarget) return

    const trimmed = this.inputTarget.value.trim()
    const isTaken = trimmed.length > 0 && this.takenValue.includes(trimmed)

    this.warningTarget.textContent = isTaken
      ? "同じ名前の参加者がいます。区別できる名前にすると分かりやすくなります"
      : ""
    this.warningTarget.classList.toggle("hidden", !isTaken)
  }

  remember() {
    if (!this.hasInputTarget) return

    try {
      localStorage.setItem(STORAGE_KEY, this.inputTarget.value.trim())
    } catch (error) {
      console.log("Failed to save name to localStorage:", error)
    }
  }

  readStoredName() {
    try {
      return localStorage.getItem(STORAGE_KEY)
    } catch (error) {
      console.log("Failed to read name from localStorage:", error)
      return null
    }
  }
}
