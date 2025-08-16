import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Real-time updates for room management
export default class extends Controller {
  static values = { roomId: String, owner: Boolean }
  static targets = ["participants", "selectionList", "countInput", "selectionHeader", "inviteUrl", "copyFeedback", "copyButton"]

  // Connection and initialization
  connect() {
    console.log('Room controller connecting...', this.roomIdValue)
    this.connectionConfig = new ConnectionConfig()
    this.setupRealtimeConnection()
  }

  disconnect() {
    this.cleanup()
  }

  // Real-time connection management
  setupRealtimeConnection() {
    this.subscription = consumer.subscriptions.create(
      { channel: 'RoomChannel', room_id: this.roomIdValue }, 
      {
        connected: () => this.handleConnectionSuccess(),
        disconnected: () => this.handleConnectionLost(),
        rejected: () => this.handleConnectionRejected(),
        received: (data) => this.handleMessage(data)
      }
    )
    
    if (this.connectionConfig.shouldStartPolling()) {
      this.startPolling()
    }
  }

  handleConnectionSuccess() {
    console.log('✅ ActionCable connected for room:', this.roomIdValue)
    this.stopPolling()
  }

  handleConnectionLost() {
    console.log('❌ ActionCable disconnected for room:', this.roomIdValue)
    this.startPolling()
  }

  handleConnectionRejected() {
    console.log('🚫 ActionCable connection rejected for room:', this.roomIdValue)
    this.startPolling()
  }

  handleMessage(data) {
    console.log('📡 ActionCable received:', data)
    
    const messageHandler = new MessageHandler(this)
    messageHandler.process(data)
  }

  // Polling fallback mechanism
  startPolling() {
    this.stopPolling()
    
    const interval = this.connectionConfig.pollingInterval
    console.log(`🔄 Starting polling every ${interval/1000} seconds for room:`, this.roomIdValue)
    
    this.pollingTimer = setInterval(() => {
      console.log('� Polling for updates...')
      this.fetchUpdates()
    }, interval)
  }

  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer)
      this.pollingTimer = null
      console.log('⏸️ Polling stopped - ActionCable active')
    }
  }

  async fetchUpdates() {
    try {
      const response = await fetch(`/rooms/${this.roomIdValue}/updates`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        const messageHandler = new MessageHandler(this)
        messageHandler.processPollingData(data)
      }
    } catch (error) {
      console.log('Polling update failed:', error)
    }
  }

  // UI rendering methods
  renderParticipants(list) {
    if (!this.hasParticipantsTarget) return
    
    console.log('🎨 Rendering participants:', list.length, 'participants')
    const renderer = new ParticipantRenderer()
    this.participantsTarget.innerHTML = renderer.render(list)
  }

  renderSelection(selected, count) {
    if (!this.hasSelectionListTarget) return
    
    const renderer = new SelectionRenderer()
    this.selectionListTarget.innerHTML = renderer.render(selected)
    this.updateSelectionHeader()
  }

  updateSelectionHeader() {
    if (this.hasSelectionHeaderTarget && this.selectionHeaderTarget.hidden) {
      this.selectionHeaderTarget.hidden = false
      this.selectionHeaderTarget.textContent = '抽選結果'
    }
  }

  // Copy functionality
  async copyInvite() {
    if (!this.hasInviteUrlTarget) return
    
    const copyHandler = new CopyHandler(this)
    await copyHandler.copyText(this.inviteUrlTarget.textContent.trim())
  }

  // Manual refresh
  refreshUpdates() {
    console.log('🔄 Manual refresh requested')
    this.fetchUpdates()
  }

  // Cleanup
  cleanup() {
    if (this.subscription) consumer.subscriptions.remove(this.subscription)
    this.stopPolling()
  }
}

// Configuration for connection behavior
class ConnectionConfig {
  constructor() {
    this.isProduction = window.location.hostname.includes('onrender.com')
    this.pollingInterval = 30000
  }

  shouldStartPolling() {
    return !this.isProduction
  }
}

// Message handling for real-time updates
class MessageHandler {
  constructor(controller) {
    this.controller = controller
  }

  process(data) {
    switch (data.type) {
      case 'ping':
        this.handlePing(data)
        break
      case 'participants':
        this.handleParticipantsUpdate(data)
        break
      case 'selection':
        this.handleSelectionUpdate(data)
        break
    }
  }

  processPollingData(data) {
    if (data.participants) {
      this.handleParticipantsUpdate({ participants: data.participants })
    }
    if (data.selection) {
      this.handleSelectionUpdate({
        selected: data.selection.selected,
        count: data.selection.count
      })
    }
  }

  handlePing(data) {
    console.log('🏓 ActionCable ping received:', data.message)
  }

  handleParticipantsUpdate(data) {
    console.log('👥 Updating participants list:', data.participants.length, 'participants')
    this.controller.renderParticipants(data.participants)
  }

  handleSelectionUpdate(data) {
    if (data.selected) {
      this.controller.renderSelection(data.selected, data.count)
      
      // 抽選後に参加者リストが消える問題の対策
      // 現在の参加者リストが空でなければ維持する
      if (this.controller.hasParticipantsTarget && 
          this.controller.participantsTarget.children.length === 0) {
        console.log('🔄 Participants list disappeared after selection, fetching updates...')
        this.controller.fetchUpdates()
      }
    }
  }
}

// Participant list rendering
class ParticipantRenderer {
  render(participants) {
    return participants.map((p, index) => 
      `<div class="flex items-center p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
        <div class="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-medium mr-3">
          ${index + 1}
        </div>
        <span class="text-gray-900 font-medium">${this.escapeHtml(p.name)}</span>
      </div>`
    ).join('')
  }

  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}

// Selection results rendering
class SelectionRenderer {
  render(selected) {
    return selected.map((p, index) => 
      `<div class="flex items-center p-4 bg-amber-50 border border-amber-200 rounded-lg">
        <div class="w-10 h-10 bg-amber-600 rounded-full flex items-center justify-center text-white font-bold mr-3">
          ${this.renderStarIcon()}
        </div>
        <span class="text-gray-900 font-semibold">${this.escapeHtml(p.name)}</span>
      </div>`
    ).join('')
  }

  renderStarIcon() {
    return `<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.196-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path>
    </svg>`
  }

  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}

// Copy to clipboard functionality
class CopyHandler {
  constructor(controller) {
    this.controller = controller
  }

  async copyText(text) {
    try {
      await this.tryClipboardAPI(text)
      this.showSuccess()
    } catch (error) {
      try {
        await this.tryFallbackMethod(text)
        this.showSuccess()
      } catch (fallbackError) {
        this.showError(fallbackError)
      }
    }
  }

  async tryClipboardAPI(text) {
    if (!navigator.clipboard?.writeText) {
      throw new Error('Clipboard API not available')
    }
    await navigator.clipboard.writeText(text)
  }

  async tryFallbackMethod(text) {
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.top = '-1000px'
    
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    
    const success = document.execCommand('copy')
    document.body.removeChild(textarea)
    
    if (!success) {
      throw new Error('execCommand returned false')
    }
  }

  showSuccess() {
    this.showFeedback('コピーしました', 1500, 'text-green-600')
  }

  showError(error) {
    console.error('Copy failed', error)
    this.showFeedback('コピー失敗', 2000, 'text-red-600')
  }

  showFeedback(message, duration, className) {
    if (!this.controller.hasCopyFeedbackTarget) return
    
    const target = this.controller.copyFeedbackTarget
    target.textContent = message
    target.className = `text-xs ${className}`
    target.style.display = 'inline'
    
    clearTimeout(this.controller._copyTimer)
    this.controller._copyTimer = setTimeout(() => {
      target.style.display = 'none'
    }, duration)
  }
}
